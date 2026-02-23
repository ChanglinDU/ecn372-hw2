# AI usage log (required disclosure)

This file documents how I used AI tools (Cursor Chat) while building this assignment repo. I wrote this to be as complete as possible and avoided inventing steps.

## 2026-02-22 — Requirements extraction + project plan

- Tool: Cursor Chat
- Prompt: "Please read the uploaded screenshots carefully and help me do all of it."
- Output summary: Extracted the grading constraints (paths, `make evaluate`, stdout format, README + AI disclosure) and planned a reproducible implementation.
- What I used:
  - Read the assignment screenshots and identified the hard requirements:
    - `test.csv` will be placed at `data/raw/test.csv`
    - `make evaluate` must print **only** `MSE: ...`
    - one final model, structured model selection, thorough README, AI usage disclosure
  - Read `OnlineNewsPopularity.names` to confirm the target (`shares`) and that `url` is non-predictive.
  - Read the `train.csv` header and noticed fields are comma-separated with a space after the comma (`, `).
- Verification: Confirmed the repo uses the required `data/raw/test.csv` path and prints only the MSE in the final evaluation script.

## 2026-02-22 — R-only modeling pipeline (final implementation)

- Tool: Cursor Chat
- Prompt: "All your code must use R; everything is based on R. You can also use polynomial variables and interaction terms."
- Output summary: Implemented an end-to-end R solution: preprocessing, polynomial feature engineering (with interactions implemented and tested), ridge regression training, and test evaluation.
- What I used:
  - Created `scripts/utils.R` with reusable functions for:
    - robust CSV reading (trim column names)
    - dropping `url` and splitting predictors/target
    - feature engineering:
      - squared (degree-2) terms for non-binary predictors (used in the final model)
      - interaction terms: `data_channel_is_*` × selected continuous predictors (implemented for comparison; not selected in the final model)
    - median imputation (fit on training, apply to test)
    - zero-variance feature removal
    - standardization (fit on training, apply to test)
    - ridge regression (closed-form fit) + prediction
    - K-fold cross-validation to select ridge penalty \(\lambda\)
  - Created `scripts/evaluate.R` that:
    - reads `train.csv` and `data/raw/test.csv`
    - selects \(\lambda\) by 5-fold CV on the training set only (seed=42)
    - fits the final ridge model on all training data
    - predicts on the test set, clips negatives to 0, computes MSE
    - prints **only** `MSE: <number>`
- Verification: Ran `Rscript scripts/evaluate.R` using a temporary local `data/raw/test.csv` (a small slice of `train.csv`) and confirmed the script prints exactly one line `MSE: ...`.

## 2026-02-22 — Makefile + reproducibility requirements

- Tool: Cursor Chat
- Prompt: "`make evaluate` must work and must print only the test MSE."
- Output summary: Added a Makefile that calls the R evaluation script without echoing commands, and added repo scaffolding needed for grading.
- What I used:
  - Added `Makefile` targets:
    - `evaluate` → `Rscript scripts/evaluate.R`
    - `model-selection` → `Rscript scripts/model_selection.R`
  - Added `data/raw/.gitkeep` so the `data/raw/` directory exists in the repo.
  - Added `.gitignore` to avoid committing grader-provided `data/raw/test.csv`.
  - Added a missing-file guard in `scripts/evaluate.R` that errors to **stderr** (not stdout) if `data/raw/test.csv` is absent.
- Verification: Confirmed `make evaluate` prints only one line (`MSE: ...`) when a valid `data/raw/test.csv` is present.

## 2026-02-22 — Structured model selection script + README write-up

- Tool: Cursor Chat
- Prompt: "Model selection must be structured (e.g., cross-validation) and visible; README must thoroughly explain choices."
- Output summary: Added an explicit model-selection script (CV comparisons) and wrote a detailed README explaining preprocessing, features, model choice, and validation.
- What I used:
  - Added `scripts/model_selection.R` to compare feature-set variants with 5-fold CV:
    - base linear
    - polynomial (squared) terms
    - polynomial + interactions
  - Wrote `README.md` describing:
    - data paths and how grading works
    - preprocessing rationale (dropping `url`, imputation, standardization, etc.)
    - polynomial + interaction features and why they help
    - ridge regression choice and why \(\lambda\) is selected by CV
    - exact commands to run (`make evaluate`, `make model-selection`)
- Verification: Ran the evaluation path locally and confirmed the README instructions match the repo behavior.

## 2026-02-22 — Performance + output cleanliness refinements

- Tool: Cursor Chat
- Prompt: "Print only `MSE: ...` to stdout—no other output."
- Output summary: Ensured the evaluation path is quiet (no warnings/messages) and made cross-validation faster.
- What I used:
  - Set `options(warn = -1)` in the R scripts to suppress warnings that could otherwise clutter console output.
  - Optimized the CV implementation in `cv_ridge()` to compute `crossprod(X)` and `crossprod(X, y)` **once per fold** and reuse them across all \(\lambda\) values.
  - Kept the Makefile targets quiet using `@` so `make` does not echo commands.
- Verification: Ran `make evaluate` locally and confirmed stdout contains only the single `MSE: ...` line.

