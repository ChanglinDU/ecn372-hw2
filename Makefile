.PHONY: evaluate train test model-selection clean metrics

R ?= Rscript

# Train the final model (silent; writes `models/final_model.rds`).
train:
	@$(R) scripts/train.R

# Evaluate on `data/raw/test.csv` and print ONLY `MSE: ...`.
test:
	@$(R) scripts/test.R

# For your own inspection (NOT used by the grader): print RMSE to stderr too.
metrics:
	@$(R) scripts/test.R --print-rmse

# Grader entrypoint: trains (or retrains) then prints test MSE.
evaluate: train test

model-selection:
	@$(R) scripts/train.R --model-selection

# Optional: remove locally generated model artifacts.
clean:
	@rm -rf models

