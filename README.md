# ECN372 HW2 — Predicting Online News Popularity (`shares`) in R

This repo trains **one final regression model** to predict the target variable **`shares`** from `train.csv` (Online News Popularity dataset).

At grading time, `test.csv` will be placed at:

- `data/raw/test.csv`

Running:

```bash
make evaluate
```

will:

1. Train the final model using `train.csv`,
2. Read the test set from `data/raw/test.csv`,
3. Predict `shares` on the test set,
4. Print **only** the test MSE to stdout, e.g.

```text
MSE: 1234.56
```

## Environment / dependencies

- **Language**: R (tested with R 4.4.x)
- **Packages**: uses base/recommended R only (no extra packages required)

## Data

- **Training data**: `train.csv` (repo root)
- **Test data (grader-provided)**: `data/raw/test.csv` (same columns; target is again `shares`)
- **Variable descriptions**: `OnlineNewsPopularity.names`

## Preprocessing choices (and why)

All preprocessing is implemented in `scripts/utils.R` and applied consistently to train and test.

- **CSV parsing**: the provided CSVs use a comma followed by a space (`, `). We read with `strip.white=TRUE` and trim column names with `trimws()` to avoid leading-space column names.
- **Drop `url`**: `url` is an identifier-like high-cardinality string and does not generalize without dedicated URL/text feature engineering.
- **Numeric conversion**: all predictors are coerced to numeric (defensive; avoids silent character/factor issues).
- **Median imputation**: if any NAs appear after parsing/coercion, they are filled using the **training-set column median**.
- **Remove constant predictors**: zero-variance columns (on the training set) are removed so they do not enter the model.
- **Standardization**: features are centered/scaled using training-set means/SDs to make ridge regularization well-behaved.
- **Non-negativity**: `shares` cannot be negative, so predictions are clipped at 0 before computing MSE.

## Feature engineering (polynomials; interactions considered)

To capture simple nonlinearities while staying interpretable, the final feature set includes:

- **Polynomial terms**: squared terms for **non-binary** predictors (degree-2 polynomials).

I also evaluated a small set of **interaction terms** (`data_channel_is_*` × selected continuous predictors), but cross-validation slightly preferred the polynomial-only feature set, so interactions are not part of the final model.

The final feature specification is defined in `default_feature_spec()` in `scripts/utils.R`.

## Final model (one model)

The submission uses a **single final model**:

- **Model class**: ridge regression (linear regression with L2 regularization)
- **Features**: original predictors + squared terms (degree-2)
- **Penalty**: \(\lambda = 10^{3.5} \approx 3162.28\), chosen by **5-fold cross-validation on the training set only** (seed fixed to 42 for reproducibility; see `make model-selection`)

Implementation details:

- Ridge is fit via the closed-form solution \((X^TX + \lambda I)^{-1}X^Ty\) on standardized predictors.
- The full training set is then refit using the selected \(\lambda\), and predictions are produced for the test set.

## Model selection (structured + visible)

The repo includes a visible model selection procedure:

- `make model-selection` runs cross-validation comparisons across feature-set variants:
  - base linear features
  - polynomial (squared) features
  - polynomial + interaction features

This script prints a small table of the best CV MSE and best \(\lambda\) for each variant, then reports the selected variant.

## Replicability

- `make evaluate` assumes only that `data/raw/test.csv` exists.
- The Makefile uses `@` to avoid echoing commands.
- The evaluation script prints **only** `MSE: ...` to stdout.

## AI usage disclosure

See `AI_USAGE.md` (in the required log format).

