# Healthee — repo-root task runner. Works from the repo root; server targets
# cd into apps/server. Run `make help` for the list.

SERVER := apps/server
UV     := uv

KNOWLEDGE_GEN := ../../packages/knowledge/tools/gen_manifest.py

.DEFAULT_GOAL := help
.PHONY: help setup setup-server lint test fix ci gate knowledge knowledge-check

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: ## Enable git hooks (runs scripts/setup-dev.sh)
	@sh scripts/setup-dev.sh

setup-server: ## Install server deps (uv sync)
	cd $(SERVER) && $(UV) sync

gate: ## Repo-wide file-length gate
	python3 scripts/check_file_length.py

lint: gate ## Lint: file-length gate + ruff check + format check + pyright
	cd $(SERVER) && $(UV) run ruff check
	cd $(SERVER) && $(UV) run ruff format --check
	cd $(SERVER) && $(UV) run pyright

test: ## Run server tests (pytest + coverage report)
	cd $(SERVER) && $(UV) run pytest

fix: ## Auto-fix: ruff --fix + ruff format
	cd $(SERVER) && $(UV) run ruff check --fix
	cd $(SERVER) && $(UV) run ruff format

knowledge: ## Regenerate the knowledge manifest + research summaries
	cd $(SERVER) && $(UV) run python $(KNOWLEDGE_GEN)

knowledge-check: ## Fail if the committed manifest is stale/hand-edited
	cd $(SERVER) && $(UV) run python $(KNOWLEDGE_GEN) --check

ci: lint test knowledge-check ## Everything CI runs locally (lint + test + knowledge)
