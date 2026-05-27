.PHONY: install-hooks lint lint-yaml format-check format-yaml clean help

SHELL := /bin/bash

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install-hooks:
	pre-commit install

lint: lint-yaml lint-python

lint-yaml:
	yamllint .

lint-python: ## Lint Python code with ruff
	ruff check .
	ruff format --check .

format: ## Auto-format Python and YAML code
	ruff check --fix .
	ruff format .
	pre-commit run yamlfmt --all-files || true

format-check: ## Check formatting without changes
	ruff format --check .
	ruff check .
	pre-commit run yamlfmt --all-files

format-yaml:
	pre-commit run yamlfmt --all-files || true

clean: ## Remove caches and temp files
	find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name '.pytest_cache' -exec rm -rf {} + 2>/dev/null || true
	rm -rf .ruff_cache

.DEFAULT_GOAL := help
