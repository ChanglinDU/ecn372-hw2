trim_colnames <- function(df) {
  names(df) <- trimws(names(df))
  df
}

read_dataset <- function(path) {
  df <- read.csv(
    file = path,
    stringsAsFactors = FALSE,
    strip.white = TRUE,
    check.names = FALSE
  )
  trim_colnames(df)
}

to_numeric <- function(x) {
  if (is.numeric(x)) return(x)
  if (is.integer(x)) return(as.numeric(x))
  if (is.logical(x)) return(as.numeric(x))
  if (is.factor(x)) return(as.numeric(as.character(x)))
  suppressWarnings(as.numeric(x))
}

split_xy <- function(df, target_col = "shares") {
  if (!(target_col %in% names(df))) {
    stop(sprintf("Expected target column '%s' in data.", target_col))
  }

  drop_cols <- intersect(c(target_col, "url"), names(df))
  x_df <- df[, setdiff(names(df), drop_cols), drop = FALSE]
  y <- df[[target_col]]

  list(x_df = x_df, y = y)
}

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

default_feature_spec <- function() {
  list(
    poly_degree = 2,
    include_interactions = FALSE,
    interaction_continuous = character(0)
  )
}

poly2_interactions_feature_spec <- function() {
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
      x_int <- matrix(0, nrow = nrow(x_mat), ncol = length(channel_cols) * length(inter_cont))
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

impute_fit <- function(x_mat) {
  med <- apply(x_mat, 2, function(col) median(col, na.rm = TRUE))
  x_imp <- x_mat
  for (j in seq_len(ncol(x_imp))) {
    idx <- is.na(x_imp[, j])
    if (any(idx)) x_imp[idx, j] <- med[j]
  }
  list(x = x_imp, med = med)
}

impute_apply <- function(x_mat, med) {
  x_imp <- x_mat
  for (j in seq_len(ncol(x_imp))) {
    idx <- is.na(x_imp[, j])
    if (any(idx)) x_imp[idx, j] <- med[j]
  }
  x_imp
}

drop_zero_variance <- function(x_train, x_test) {
  v <- apply(x_train, 2, var)
  keep <- which(is.finite(v) & v > 0)
  list(
    x_train = x_train[, keep, drop = FALSE],
    x_test = x_test[, keep, drop = FALSE],
    keep_idx = keep
  )
}

standardize_fit <- function(x_mat) {
  mu <- colMeans(x_mat)
  sd <- apply(x_mat, 2, sd)
  sd[sd == 0] <- 1
  x_std <- sweep(x_mat, 2, mu, "-")
  x_std <- sweep(x_std, 2, sd, "/")
  list(x = x_std, mu = mu, sd = sd)
}

standardize_apply <- function(x_mat, mu, sd) {
  x_std <- sweep(x_mat, 2, mu, "-")
  sweep(x_std, 2, sd, "/")
}

ridge_fit <- function(x_std, y, lambda) {
  y_mean <- mean(y)
  y_center <- y - y_mean

  xtx <- crossprod(x_std)
  xty <- crossprod(x_std, y_center)

  a <- xtx
  diag(a) <- diag(a) + lambda
  beta <- solve(a, xty)

  list(intercept = y_mean, beta = beta, lambda = lambda)
}

ridge_predict <- function(model, x_std) {
  as.vector(model$intercept + x_std %*% model$beta)
}

ridge_fit_from_crossprod <- function(xtx, xty, y_mean, lambda) {
  a <- xtx
  diag(a) <- diag(a) + lambda
  beta <- solve(a, xty)
  list(intercept = y_mean, beta = beta, lambda = lambda)
}

cv_ridge <- function(x_mat, y, lambdas, k = 5, seed = 42) {
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

