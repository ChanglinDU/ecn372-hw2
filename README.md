# ECN 372 HW2 — Predict article popularity (`shares`) in R

This repository builds **one final predictive model** for article popularity (`shares`) using the provided training set `train.csv`.

At grading time, the instructor will add **`data/raw/test.csv`** and run:

```bash
make evaluate
```

Your repo must then print **only** the test MSE to stdout (one line):

```text
MSE: 1234.56
```

## Environment

- **R**: tested with R 4.4.x (should work with any modern R \(\ge\) 4.0)
- **Packages**: base/recommended R only (no package installation step required)

## Usage

From the project root directory:

- **Model selection (optional, but recommended for transparency)**:

```bash
make model-selection
```

- **Grader entrypoint** (trains + evaluates and prints only MSE):

```bash
make evaluate
```

### What `make evaluate` does

1. Runs `scripts/train.R` to fit the **single final model** using `train.csv` and saves it to `models/final_model.rds` (no stdout output).
2. Runs `scripts/test.R` to:
   - read `data/raw/test.csv`,
   - generate predictions,
   - compute test MSE,
   - print **only** `MSE: ...`.

If `data/raw/test.csv` is missing, `scripts/test.R` exits with an error message to **stderr** (so it does not pollute stdout).

## Model selection and choices (structured + visible)

All code is in the `scripts/` folder and is intentionally split into:

- `scripts/setup.R`: shared constants + helper functions (preprocessing, features, ridge, CV)
- `scripts/train.R`: training + (optional) model selection output
- `scripts/test.R`: evaluation (prints only MSE)

### Final model (one model)

The submission uses **one** final model:

- **Model**: ridge regression (linear model with L2 regularization)
- **Target**: `shares`
- **Final feature set**: all numeric predictors (excluding `url`) plus **squared (degree‑2) polynomial terms** for non-binary predictors
- **Penalty**: \(\lambda = 10^{3.5} \approx 3162.28\)
- **Seed**: 42 for reproducibility

The penalty and feature set are chosen using **5-fold cross-validation** (run `make model-selection` to see the comparison table).

### Preprocessing (applied consistently to train and test)

Implemented in `scripts/setup.R`:

- **CSV parsing**: trims column names and strips whitespace after commas to avoid accidental leading spaces in variable names.
- **Drop `url`**: it is identifier-like and does not generalize without special URL/text feature engineering.
- **Numeric coercion**: defensively converts predictors to numeric to avoid factor/character surprises.
- **Median imputation**: fills missing values using training-set column medians.
- **Constant-feature removal**: drops zero-variance predictors based on the training set.
- **Standardization**: centers/scales using training-set means and SDs (important for ridge).
- **Non-negativity**: clips predictions at 0 (since `shares` cannot be negative).

### Polynomial and interaction terms

- **Polynomials**: degree‑2 (squared) terms are used in the final model to capture simple nonlinearities.
- **Interactions**: a small set of channel × continuous interactions is implemented (`feature_spec_poly2_interactions()`), but the CV comparison slightly favored polynomial-only features, so interactions are not part of the final submitted model.

## Repository contents (what each file is for)

- `Makefile`: entrypoints (`evaluate`, `train`, `test`, `model-selection`, `clean`)
- `scripts/setup.R`: paths/constants + preprocessing + feature engineering + ridge + CV helpers
- `scripts/train.R`: trains final model artifact (`models/final_model.rds`); `--model-selection` prints CV results
- `scripts/test.R`: loads model + evaluates on `data/raw/test.csv` + prints only MSE
- `data/raw/`: location where the grader will place `test.csv`
  - `data/raw/.gitignore`: keeps the folder in git but ignores raw data files
- `.gitignore`: ignores `data/raw/test.csv` and locally generated model artifacts
- `train.csv`: training data
- `OnlineNewsPopularity.names`: variable descriptions / dataset documentation
- `AI_USAGE.md`: AI usage disclosure log (required)
- `README.md`: this file

## AI usage disclosure

See `AI_USAGE.md` (required log format).

