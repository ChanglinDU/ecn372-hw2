options(warn = -1)
options(stringsAsFactors = FALSE)

# -------------------------------------------------------------------------
# Training script
#
# This script has two modes:
#
# - Default (no args): trains the single final model on all of `train.csv` and
#   saves a compact model artifact to `models/final_model.rds`.
#   This mode is intentionally SILENT (no stdout) so `make evaluate` prints only
#   the final test MSE.
#
# - `--model-selection`: runs structured cross-validation comparisons and prints
#   a small results table (used by `make model-selection`).
# -------------------------------------------------------------------------

# Shared setup (paths, feature specs, preprocessing + modeling helpers)
source(file.path(getwd(), "scripts", "setup.R"))

args <- commandArgs(trailingOnly = TRUE)

run_model_selection <- function() {
  # Compare a few feature-set variants and tune lambda with 5-fold CV.
  set.seed(SEED)

  train_df <- read_dataset(TRAIN_PATH)
  spl <- split_xy(train_df, target_col = TARGET)

  specs <- list(
    base_linear = feature_spec_base(),
    poly2 = feature_spec_poly2(),
    poly2_plus_interactions = feature_spec_poly2_interactions()
  )

  results <- data.frame(
    spec = character(0),
    best_lambda = numeric(0),
    cv_mse_mean = numeric(0),
    cv_mse_sd = numeric(0),
    stringsAsFactors = FALSE
  )

  for (name in names(specs)) {
    spec <- specs[[name]]

    x_raw <- make_feature_matrix(spl$x_df, spec)
    keep_idx <- drop_zero_variance_idx(x_raw)
    x <- x_raw[, keep_idx, drop = FALSE]

    cv <- cv_ridge(x, spl$y, lambdas = LAMBDA_GRID, k = 5, seed = SEED)
    best_idx <- which.min(cv$mse_mean)

    results <- rbind(
      results,
      data.frame(
        spec = name,
        best_lambda = cv$lambda[best_idx],
        cv_mse_mean = cv$mse_mean[best_idx],
        cv_mse_sd = cv$mse_sd[best_idx],
        stringsAsFactors = FALSE
      )
    )
  }

  results <- results[order(results$cv_mse_mean), ]

  cat("Cross-validated metric: MSE (lower is better)\n")
  cat(sprintf("CV: 5-fold, seed=%s\n\n", SEED))
  print(results, row.names = FALSE)

  cat(sprintf("\nSelected final feature set: %s\n", results$spec[1]))
  cat(sprintf("Selected lambda: %.3f\n", results$best_lambda[1]))
}

train_final_model <- function() {
  # Fit the final model on the full training set using the pre-selected
  # `FINAL_FEATURE_SPEC` and `FINAL_LAMBDA` from setup.R.
  set.seed(SEED)

  train_df <- read_dataset(TRAIN_PATH)
  spl <- split_xy(train_df, target_col = TARGET)

  # Build the design matrix (original + engineered features) and drop constants.
  x_raw <- make_feature_matrix(spl$x_df, FINAL_FEATURE_SPEC)
  keep_idx <- drop_zero_variance_idx(x_raw)
  x <- x_raw[, keep_idx, drop = FALSE]

  # Preprocess using training-only statistics.
  imp <- impute_fit(x)
  x_imp <- imp$x

  std <- standardize_fit(x_imp)
  x_std <- std$x

  # Closed-form ridge fit on standardized predictors.
  model <- ridge_fit(x_std, spl$y, FINAL_LAMBDA)

  # Persist everything needed for deterministic inference on the test set.
  # We store preprocessing stats + coefficient vector (instead of the whole data).
  artifact <- list(
    created_at = as.character(Sys.time()),
    target = TARGET,
    feature_spec_name = FINAL_SPEC_NAME,
    feature_spec = FINAL_FEATURE_SPEC,
    lambda = FINAL_LAMBDA,
    keep_idx = keep_idx,
    feature_names = colnames(x),
    impute_median = imp$med,
    scale_mean = std$mu,
    scale_sd = std$sd,
    intercept = model$intercept,
    beta = model$beta,
    seed = SEED
  )

  # Write the artifact to disk so `scripts/test.R` can load it in a new R session.
  dir.create(MODELS_DIR, showWarnings = FALSE, recursive = TRUE)
  saveRDS(artifact, MODEL_PATH)
}

if ("--model-selection" %in% args) {
  run_model_selection()
} else {
  # Silent training mode (used by `make evaluate`).
  train_final_model()
}

