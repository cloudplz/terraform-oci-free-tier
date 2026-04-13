.PHONY: help docs examples-validate fmt pre-commit test validate

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

fmt: ## Format Terraform code recursively
	terraform fmt -recursive

validate: ## Validate the root module
	terraform init -backend=false
	terraform validate

examples-validate: ## Validate all example configurations
	@for dir in examples/*/; do \
		terraform -chdir="$$dir" init -backend=false; \
		terraform -chdir="$$dir" validate; \
	done

test: ## Run Terraform tests
	terraform init -backend=false
	terraform test

pre-commit: ## Run all pre-commit hooks
	pre-commit run -a

docs: ## Inject terraform-docs tables into README.md
	terraform-docs .
