options(warn = -1)
options(stringsAsFactors = FALSE)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else NA_character_
script_path <- if (!is.na(script_path)) normalizePath(script_path) else NA_character_

project_root <- if (!is.na(script_path)) dirname(dirname(script_path)) else getwd()
setwd(project_root)

source(file.path("scripts", "utils.R"))

train_df <- read_dataset("train.csv")
train_split <- split_xy(train_df, target_col = "shares")

lambdas <- 10^seq(-2, 4, length.out = 25)

spec_base <- list(poly_degree = 1, include_interactions = FALSE, interaction_continuous = character(0))
spec_poly <- default_feature_spec()
spec_poly_int <- poly2_interactions_feature_spec()

specs <- list(
  base_linear = spec_base,
  poly2 = spec_poly,
  poly2_plus_interactions = spec_poly_int
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
  x_raw <- make_feature_matrix(train_split$x_df, spec)
  v <- apply(x_raw, 2, var)
  keep <- which(is.finite(v) & v > 0)
  x <- x_raw[, keep, drop = FALSE]

  cv <- cv_ridge(x, train_split$y, lambdas = lambdas, k = 5, seed = 42)
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
cat("CV: 5-fold, seed=42\n\n")
print(results, row.names = FALSE)

cat("\nSelected final feature set:", results$spec[1], "\n")
cat("Selected lambda:", results$best_lambda[1], "\n")

