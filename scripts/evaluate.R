options(warn = -1)
options(stringsAsFactors = FALSE)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else NA_character_
script_path <- if (!is.na(script_path)) normalizePath(script_path) else NA_character_

project_root <- if (!is.na(script_path)) dirname(dirname(script_path)) else getwd()
setwd(project_root)

source(file.path("scripts", "utils.R"))

train_path <- file.path("train.csv")
test_path <- file.path("data", "raw", "test.csv")

if (!file.exists(test_path)) {
  cat(sprintf("Missing test data at: %s\n", normalizePath(test_path, mustWork = FALSE)), file = stderr())
  cat("Place test.csv at data/raw/test.csv then rerun `make evaluate`.\n", file = stderr())
  quit(status = 2)
}

train_df <- read_dataset(train_path)
test_df <- read_dataset(test_path)

train_split <- split_xy(train_df, target_col = "shares")
test_split <- split_xy(test_df, target_col = "shares")

feature_spec <- default_feature_spec()

x_train_raw <- make_feature_matrix(train_split$x_df, feature_spec)
x_test_raw <- make_feature_matrix(test_split$x_df, feature_spec)

dzv <- drop_zero_variance(x_train_raw, x_test_raw)
x_train <- dzv$x_train
x_test <- dzv$x_test

lambda_final <- 10^3.5

# Fit final model on full training set
imp <- impute_fit(x_train)
x_train_imp <- imp$x
x_test_imp <- impute_apply(x_test, imp$med)

std <- standardize_fit(x_train_imp)
x_train_std <- std$x
x_test_std <- standardize_apply(x_test_imp, std$mu, std$sd)

model <- ridge_fit(x_train_std, train_split$y, lambda_final)
pred <- ridge_predict(model, x_test_std)
pred <- pmax(pred, 0)

mse <- mean((test_split$y - pred)^2)
cat(sprintf("MSE: %.2f\n", mse))

