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
  - Created shared preprocessing/modeling helpers (initially in `scripts/utils.R`, later refactored into `scripts/setup.R`) for:
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
  - Created the evaluation workflow (initially `scripts/evaluate.R`, later refactored into `scripts/test.R` + `scripts/train.R`) that:
    - reads `train.csv` and `data/raw/test.csv`
    - selects \(\lambda\) by 5-fold CV on the training set only (seed=42)
    - fits the final ridge model on all training data
    - predicts on the test set, clips negatives to 0, computes MSE
    - prints **only** `MSE: <number>`
- Verification: Ran the evaluation path using a temporary local `data/raw/test.csv` (a small slice of `train.csv`) and confirmed the script prints exactly one line `MSE: ...`.

## 2026-02-22 — Makefile + reproducibility requirements

- Tool: Cursor Chat
- Prompt: "`make evaluate` must work and must print only the test MSE."
- Output summary: Added a Makefile that calls the R evaluation script without echoing commands, and added repo scaffolding needed for grading.
- What I used:
  - Added `Makefile` targets:
    - `evaluate` → `Rscript scripts/train.R` then `Rscript scripts/test.R`
    - `model-selection` → `Rscript scripts/train.R --model-selection`
  - Added `data/raw/.gitignore` so the `data/raw/` directory exists in the repo (Git cannot track empty folders).
  - Added `.gitignore` to avoid committing grader-provided `data/raw/test.csv`.
  - Added a missing-file guard in `scripts/test.R` that errors to **stderr** (not stdout) if `data/raw/test.csv` is absent.
- Verification: Confirmed `make evaluate` prints only one line (`MSE: ...`) when a valid `data/raw/test.csv` is present.

## 2026-02-22 — Structured model selection script + README write-up

- Tool: Cursor Chat
- Prompt: "Model selection must be structured (e.g., cross-validation) and visible; README must thoroughly explain choices."
- Output summary: Added an explicit model-selection script (CV comparisons) and wrote a detailed README explaining preprocessing, features, model choice, and validation.
- What I used:
  - Implemented model selection inside `scripts/train.R --model-selection` to compare feature-set variants with 5-fold CV:
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

## 2026-03-01 — Refactor scripts into `setup.R` / `train.R` / `test.R` format

- Tool: Cursor Chat
- Prompt: "Rename my 3 R files under scripts as setup.R, test.R, and train.R, and make them follow the same overall format as my screenshots (without copying)."
- Output summary: Renamed and reorganized the R code into three scripts with a setup/train/test layout and updated the repo wiring accordingly.
- What I used:
  - Created `scripts/setup.R` to hold:
    - project constants (paths, target, seed)
    - feature specs (polynomial terms; interactions available for comparison)
    - shared helper functions (CSV parsing, feature building, ridge + CV)
  - Created `scripts/train.R` to:
    - (default) train the **single final model** and save it to `models/final_model.rds` without printing to stdout
    - (`--model-selection`) run 5-fold CV comparisons and print the selection table
  - Created `scripts/test.R` to:
    - load the saved model
    - compute predictions on `data/raw/test.csv`
    - print **only** `MSE: ...` to stdout
  - Updated the `Makefile` so `make evaluate` runs `train.R` then `test.R`.
  - Removed the older script filenames after refactoring.
- Verification: Re-ran `make evaluate` with a temporary local `data/raw/test.csv` and confirmed output remained exactly one line: `MSE: ...`.

## 2026-03-01 — Documentation pass (code descriptions + concrete README)

- Tool: Cursor Chat
- Prompt: "Add descriptions for each code and for every file in the repo sidebar; make README concrete; update AI usage log."
- Output summary: Added clear, sectioned documentation to each script and improved README/Makefile explanations while keeping the grading output contract unchanged.
- What I used:
  - Updated `scripts/setup.R` with:
    - a detailed header explaining what the file provides (paths, specs, preprocessing, ridge, CV)
    - explanatory comments for each helper function and each major pipeline step
  - Updated `scripts/train.R` with:
    - clear documentation of the two modes (silent training vs `--model-selection`)
    - comments explaining how the final model artifact is built and saved
  - Updated `scripts/test.R` with:
    - explicit “stdout contract” documentation (print only `MSE: ...`)
    - comments explaining model loading, feature construction, and preprocessing application
  - Updated `Makefile` with:
    - documented targets
    - added `train` and `test` targets and made `evaluate` depend on them
    - added a `clean` target to remove local model artifacts
  - Updated `.gitignore` and `data/raw/.gitignore` with clearer intent and removed accidental duplication in `data/raw/.gitignore`.
  - Rewrote `README.md` to be more concrete and closer to the assignment expectations:
    - environment requirements
    - exact usage commands
    - what `make evaluate` does step-by-step
    - model choice + structured selection
    - a “repository contents” section describing every file/folder in the sidebar
- Verification: Re-ran `make evaluate` with a temporary local `data/raw/test.csv` and confirmed stdout is still exactly one line `MSE: ...`.

## 2026-03-01 — Repo-wide R-only compliance check

- Tool: Cursor Chat
- Prompt: "Revise all files so the code is R code, and check every single file."
- Output summary: Verified the repo contains only R scripts for modeling/evaluation and removed any leftover non-R modeling code or references.
- What I used:
  - Scanned the repo for non-R code artifacts (e.g., Python files, `requirements.txt`, `src/`, serialized model files from other languages).
  - Searched for leftover references to Python/scikit-learn tooling in documentation.
  - Confirmed `scripts/` contains exactly:
    - `setup.R`
    - `train.R`
    - `test.R`
  - Confirmed `Makefile` runs `Rscript` only.
- Verification: Re-ran `make evaluate` (temporary test file) and confirmed stdout output is still exactly one line: `MSE: ...`.

## 2026-03-01 — Target log transform revision (log(1 + shares))

- Tool: Cursor Chat
- Prompt: "My professor said the MSE is too big; I can use the log form. Please revise it and update README.md and AI_USAGE.md."
- Output summary: Updated the final model to train on `log(1 + shares)` and inverse-transform predictions back to `shares` for MSE, while keeping `make evaluate` output exactly one line.
- What I used:
  - Added target-transform helpers in `scripts/setup.R`:
    - `transform_target()` for `log1p(shares)`
    - `inverse_transform_target()` to map predictions back to `shares`
    - `compute_smearing()` (Duan smearing factor) to reduce bias when back-transforming
  - Updated cross-validation to tune \(\lambda\) under the log-target approach (`cv_ridge_log1p()`), while still evaluating MSE on the original `shares` scale.
  - Updated `scripts/train.R` to:
    - fit ridge on the transformed target
    - compute and store a smearing factor in the saved model artifact
  - Updated `scripts/test.R` to:
    - predict on the transformed scale
    - inverse-transform predictions back to `shares` using the stored smearing factor
    - compute and print test MSE on the original scale
  - Updated `README.md` to describe the log-target choice and how evaluation is done on the original scale.
- Verification: Re-ran `make evaluate` with a temporary local `data/raw/test.csv` and confirmed stdout is still exactly one line: `MSE: ...`.

## 2026-03-01 — Add RMSE computation (without breaking grader output)

- Tool: Cursor Chat
- Prompt: "Did you calculate RMSE? If no, add it to the steps/files."
- Output summary: Added RMSE (\(\sqrt{\text{MSE}}\)) computation to the evaluation script while keeping `make evaluate` stdout exactly one line (`MSE: ...`).
- What I used:
  - Updated `scripts/test.R` to compute `rmse <- sqrt(mse)` every run.
  - Kept the grading contract intact by printing only MSE to stdout.
  - Added an optional flag `--print-rmse` that prints RMSE to **stderr** (so it does not pollute stdout).
  - Added a `make metrics` target for convenient local inspection.
  - Updated `README.md` to document how to view RMSE.
- Verification: Re-ran `make evaluate` and confirmed stdout is still exactly one line `MSE: ...`.

