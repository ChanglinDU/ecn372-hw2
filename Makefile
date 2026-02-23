.PHONY: evaluate model-selection

R ?= Rscript

evaluate:
	@$(R) scripts/evaluate.R

model-selection:
	@$(R) scripts/model_selection.R

