# =========================================================================
# ECN 372 HW2: project setup + shared utilities
#
# This file is sourced by `scripts/train.R` and `scripts/test.R`.
#
# It centralizes:
# - project paths + global constants
# - feature engineering specifications (polynomials + optional interactions)
# - preprocessing helpers (read CSV, drop identifier columns, impute, scale)
# - ridge regression (closed-form) + K-fold cross-validation for lambda tuning
#
# Important: the Makefile runs scripts from the project root, so using
# `PROJECT_ROOT <- getwd()` is the expected/normal execution path.
# =========================================================================

options(stringsAsFactors = FALSE)

# -------------------------------------------------------------------------
# Project paths + global constants
# -------------------------------------------------------------------------

# Root of the repository (expected current working directory when using make)
PROJECT_ROOT <- getwd()

# Name of the target variable we predict
TARGET <- "shares"

# Fixed seed used for cross-validation splits and any randomized steps
SEED <- 42

# Canonical file locations used by the grading script
TRAIN_PATH <- file.path(PROJECT_ROOT, "train.csv")
TEST_PATH <- file.path(PROJECT_ROOT, "data", "raw", "test.csv")
MODELS_DIR <- file.path(PROJECT_ROOT, "models")
MODEL_PATH <- file.path(MODELS_DIR, "final_model.rds")

# -------------------------------------------------------------------------
# Dependencies
# -------------------------------------------------------------------------

# This project intentionally uses only base/recommended R so the repo is
# runnable without installing extra packages on the grader's machine.
required_packages <- character(0)
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  stop("Missing required packages: ", paste(missing_packages, collapse = ", "))
}

# -------------------------------------------------------------------------
# Feature specifications (polynomials + optional interactions)
# -------------------------------------------------------------------------

# Baseline: raw predictors only (no polynomial terms, no interactions).
feature_spec_base <- function() {
  list(poly_degree = 1, include_interactions = FALSE, interaction_continuous = character(0))
}

# Polynomial-only: include squared terms for non-binary predictors.
feature_spec_poly2 <- function() {
  list(poly_degree = 2, include_interactions = FALSE, interaction_continuous = character(0))
}

# Polynomial + interactions: channel dummies × selected continuous predictors.
# This is implemented for comparison, but may or may not be selected by CV.
feature_spec_poly2_interactions <- function() {
  list(
    poly_degree = 2,
    include_interactions = TRUE,
    interaction_continuous = c(
      "n_tokens_title",
      "n_tokens_content",
      "num_hrefs",
      "num_self_hrefs",
      "num_imgs",
      "num_videos",
      "average_token_length",
      "num_keywords",
      "kw_avg_avg",
      "self_reference_avg_sharess",
      "global_subjectivity",
      "global_sentiment_polarity",
      "rate_positive_words",
      "rate_negative_words"
    )
  )
}

# -------------------------------------------------------------------------
# Final model choice (single model used by `make evaluate`)
# -------------------------------------------------------------------------

# The final chosen feature set and ridge penalty are selected via CV
# (see `make model-selection` / `scripts/train.R --model-selection`).
FINAL_SPEC_NAME <- "poly2"
FINAL_FEATURE_SPEC <- feature_spec_poly2()
FINAL_LAMBDA <- 10^3.5

# Ridge penalty grid used during model selection (log-spaced)
LAMBDA_GRID <- 10^seq(-2, 4, length.out = 25)

# -------------------------------------------------------------------------
# Data loading + preprocessing helpers
# -------------------------------------------------------------------------

# Trim whitespace from column names (defensive against CSV formatting quirks).
trim_colnames <- function(df) {
  names(df) <- trimws(names(df))
  df
}

# Read a CSV into a data.frame with stable column names (no auto-renaming).
read_dataset <- function(path) {
  df <- read.csv(
    file = path,
    stringsAsFactors = FALSE,
    strip.white = TRUE,
    check.names = FALSE
  )
  trim_colnames(df)
}

# Convert a vector to numeric when possible (avoids factor/character pitfalls).
to_numeric <- function(x) {
  if (is.numeric(x)) return(x)
  if (is.integer(x)) return(as.numeric(x))
  if (is.logical(x)) return(as.numeric(x))
  if (is.factor(x)) return(as.numeric(as.character(x)))
  suppressWarnings(as.numeric(x))
}

# Split a data.frame into predictors (X) and target (y).
# Drops `url` by design because it's identifier-like.
split_xy <- function(df, target_col = TARGET) {
  if (!(target_col %in% names(df))) {
    stop(sprintf("Expected target column '%s' in data.", target_col))
  }

  drop_cols <- intersect(c(target_col, "url"), names(df))
  x_df <- df[, setdiff(names(df), drop_cols), drop = FALSE]
  y <- df[[target_col]]

  list(x_df = x_df, y = y)
}

# Detect binary 0/1 columns (used to avoid squaring dummy variables).
infer_binary_cols <- function(x_df) {
  is_binary <- vapply(
    x_df,
    function(col) {
      col <- to_numeric(col)
      u <- unique(col[!is.na(col)])
      length(u) > 0 && all(u %in% c(0, 1))
    },
    logical(1)
  )
  names(is_binary)[is_binary]
}

# Build the numeric feature matrix given a feature specification.
#
# - Always includes the original numeric predictors.
# - Optionally adds squared terms (degree-2) for non-binary predictors.
# - Optionally adds a curated set of interaction terms.
make_feature_matrix <- function(x_df, feature_spec) {
  x_num <- as.data.frame(lapply(x_df, to_numeric))
  x_mat <- as.matrix(x_num)
  cols <- colnames(x_mat)

  # Polynomial terms (squared) for non-binary numeric predictors
  binary_cols <- intersect(infer_binary_cols(x_df), cols)
  cont_cols <- setdiff(cols, binary_cols)

  blocks <- list(x_mat)

  if (!is.null(feature_spec$poly_degree) && feature_spec$poly_degree >= 2) {
    if (length(cont_cols) > 0) {
      x_sq <- x_mat[, cont_cols, drop = FALSE]^2
      colnames(x_sq) <- paste0(cont_cols, "_sq")
      blocks <- c(blocks, list(x_sq))
    }
  }

  # Interaction terms: channel dummies × selected continuous predictors
  if (isTRUE(feature_spec$include_interactions)) {
    channel_cols <- grep("^data_channel_is_", cols, value = TRUE)
    inter_cont <- intersect(feature_spec$interaction_continuous, cont_cols)

    if (length(channel_cols) > 0 && length(inter_cont) > 0) {
      x_int <- matrix(
        0,
        nrow = nrow(x_mat),
        ncol = length(channel_cols) * length(inter_cont)
      )
      int_names <- character(ncol(x_int))
      k <- 1
      for (cname in channel_cols) {
        for (vname in inter_cont) {
          x_int[, k] <- x_mat[, cname] * x_mat[, vname]
          int_names[k] <- paste0(cname, "_x_", vname)
          k <- k + 1
        }
      }
      colnames(x_int) <- int_names
      blocks <- c(blocks, list(x_int))
    }
  }

  out <- do.call(cbind, blocks)
  storage.mode(out) <- "double"
  out
}

# Return indices of non-constant columns (variance > 0).
drop_zero_variance_idx <- function(x_mat) {
  v <- apply(x_mat, 2, var)
  which(is.finite(v) & v > 0)
}

# Fit-time median imputation (learn medians on training data).
impute_fit <- function(x_mat) {
  med <- apply(x_mat, 2, function(col) median(col, na.rm = TRUE))
  x_imp <- x_mat
  for (j in seq_len(ncol(x_imp))) {
    idx <- is.na(x_imp[, j])
    if (any(idx)) x_imp[idx, j] <- med[j]
  }
  list(x = x_imp, med = med)
}

# Apply median imputation using precomputed training medians.
impute_apply <- function(x_mat, med) {
  x_imp <- x_mat
  for (j in seq_len(ncol(x_imp))) {
    idx <- is.na(x_imp[, j])
    if (any(idx)) x_imp[idx, j] <- med[j]
  }
  x_imp
}

# Fit-time standardization (learn mean/SD on training data).
standardize_fit <- function(x_mat) {
  mu <- colMeans(x_mat)
  sd <- apply(x_mat, 2, sd)
  sd[sd == 0] <- 1

  x_std <- sweep(x_mat, 2, mu, "-")
  x_std <- sweep(x_std, 2, sd, "/")

  list(x = x_std, mu = mu, sd = sd)
}

# Apply standardization using precomputed training mean/SD.
standardize_apply <- function(x_mat, mu, sd) {
  x_std <- sweep(x_mat, 2, mu, "-")
  sweep(x_std, 2, sd, "/")
}

# -------------------------------------------------------------------------
# Ridge regression (closed-form) + cross-validation
# -------------------------------------------------------------------------

# Core ridge solver using precomputed cross-products.
# This is used to speed up CV by reusing X'X and X'y across lambdas.
ridge_fit_from_crossprod <- function(xtx, xty, y_mean, lambda) {
  a <- xtx
  diag(a) <- diag(a) + lambda
  beta <- solve(a, xty)
  list(intercept = y_mean, beta = beta, lambda = lambda)
}

# Ridge fit on standardized X (internally centers y with an explicit intercept).
ridge_fit <- function(x_std, y, lambda) {
  y_mean <- mean(y)
  y_center <- y - y_mean
  xtx <- crossprod(x_std)
  xty <- crossprod(x_std, y_center)
  ridge_fit_from_crossprod(xtx, xty, y_mean, lambda)
}

# Ridge predictions on standardized X.
ridge_predict <- function(model, x_std) {
  as.vector(model$intercept + x_std %*% model$beta)
}

# K-fold CV over a lambda grid.
#
# Notes:
# - Imputation + scaling are refit on each training fold and applied to the
#   corresponding validation fold (prevents leakage).
# - Predictions are clipped at 0 because shares cannot be negative.
cv_ridge <- function(x_mat, y, lambdas, k = 5, seed = SEED) {
  set.seed(seed)
  n <- length(y)
  folds <- sample(rep(seq_len(k), length.out = n))

  mse_mat <- matrix(NA_real_, nrow = length(lambdas), ncol = k)

  for (f in seq_len(k)) {
    idx_val <- folds == f
    idx_tr <- !idx_val

    x_tr <- x_mat[idx_tr, , drop = FALSE]
    y_tr <- y[idx_tr]
    x_val <- x_mat[idx_val, , drop = FALSE]
    y_val <- y[idx_val]

    imp <- impute_fit(x_tr)
    x_tr_imp <- imp$x
    x_val_imp <- impute_apply(x_val, imp$med)

    std <- standardize_fit(x_tr_imp)
    x_tr_std <- std$x
    x_val_std <- standardize_apply(x_val_imp, std$mu, std$sd)

    y_mean <- mean(y_tr)
    y_center <- y_tr - y_mean
    xtx <- crossprod(x_tr_std)
    xty <- crossprod(x_tr_std, y_center)

    for (i in seq_along(lambdas)) {
      lambda <- lambdas[i]
      model <- ridge_fit_from_crossprod(xtx, xty, y_mean, lambda)
      pred <- ridge_predict(model, x_val_std)
      pred <- pmax(pred, 0)
      mse_mat[i, f] <- mean((y_val - pred)^2)
    }
  }

  data.frame(
    lambda = lambdas,
    mse_mean = rowMeans(mse_mat),
    mse_sd = apply(mse_mat, 1, sd),
    stringsAsFactors = FALSE
  )
}

