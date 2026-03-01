options(warn = -1)
options(stringsAsFactors = FALSE)

# -------------------------------------------------------------------------
# Test / evaluation script
#
# Responsibilities:
# - read `data/raw/test.csv`
# - load the trained model artifact saved by `scripts/train.R`
# - generate predictions and compute test MSE
#
# Output contract (important for grading):
# - print ONLY: `MSE: <number>` to stdout
# - if the test file is missing, write the error to stderr and exit non-zero
# -------------------------------------------------------------------------

# Shared setup (paths, helper functions). Assumes run from repo root.
source(file.path(getwd(), "scripts", "setup.R"))

# Guardrail: the grader will place the file here; if it's not present we fail
# fast with a clear message (to stderr so stdout stays clean).
if (!file.exists(TEST_PATH)) {
  cat(sprintf("Missing test data at: %s\n", normalizePath(TEST_PATH, mustWork = FALSE)), file = stderr())
  cat("Place test.csv at data/raw/test.csv then rerun `make evaluate`.\n", file = stderr())
  quit(status = 2)
}

# Train if needed (normally `make evaluate` runs train first).
# This keeps `scripts/test.R` usable on its own while staying quiet.
if (!file.exists(MODEL_PATH)) {
  system2("Rscript", args = c(file.path("scripts", "train.R")), stdout = TRUE, stderr = TRUE)
}

# Load the saved model artifact (preprocessing stats + coefficients).
model_obj <- readRDS(MODEL_PATH)

# Read test data and separate predictors/target.
test_df <- read_dataset(TEST_PATH)
spl <- split_xy(test_df, target_col = model_obj$target)

# Build the engineered feature matrix and keep the columns used in training.
x_raw <- make_feature_matrix(spl$x_df, model_obj$feature_spec)
x <- x_raw[, model_obj$keep_idx, drop = FALSE]

# Ensure the test matrix matches the training column order (by name).
# This is defensive: it prevents subtle mistakes if column ordering changes.
if (!is.null(model_obj$feature_names) && length(model_obj$feature_names) == ncol(x)) {
  if (all(model_obj$feature_names %in% colnames(x))) {
    x <- x[, model_obj$feature_names, drop = FALSE]
  }
}

# Apply training-fitted preprocessing, then predict.
x_imp <- impute_apply(x, model_obj$impute_median)
x_std <- standardize_apply(x_imp, model_obj$scale_mean, model_obj$scale_sd)

pred <- as.vector(model_obj$intercept + x_std %*% model_obj$beta)
pred <- pmax(pred, 0)

# Compute test MSE on the original `shares` scale.
mse <- mean((spl$y - pred)^2)
cat(sprintf("MSE: %.2f\n", mse))

