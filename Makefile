# =========================================================================== #
# Observability & DevOps Lab — automação de operação
# `make help` lista todos os alvos disponíveis.
# =========================================================================== #
COMPOSE := docker compose
SHELL   := /bin/bash

.DEFAULT_GOAL := help

## ---------------------------------------------------------------------------
## Stack
## ---------------------------------------------------------------------------

.PHONY: up
up: ## Sobe toda a stack em background (build + start)
	$(COMPOSE) up -d --build
	@echo ""
	@echo "Stack no ar:"
	@echo "  API          -> http://localhost:8000  (/docs, /metrics)"
	@echo "  Grafana      -> http://localhost:3000  (admin / admin)"
	@echo "  Prometheus   -> http://localhost:9091"
	@echo "  Alertmanager -> http://localhost:9093"
	@echo "  Loki         -> http://localhost:3100"

.PHONY: down
down: ## Derruba a stack (mantém os volumes)
	$(COMPOSE) down

.PHONY: clean
clean: ## Derruba a stack e REMOVE volumes/dados
	$(COMPOSE) down -v

.PHONY: ps
ps: ## Lista o estado dos serviços
	$(COMPOSE) ps

.PHONY: logs
logs: ## Segue os logs de todos os serviços
	$(COMPOSE) logs -f

.PHONY: restart
restart: down up ## Reinicia a stack

## ---------------------------------------------------------------------------
## Qualidade e testes
## ---------------------------------------------------------------------------

.PHONY: test
test: test-api test-worker ## Roda todos os testes (API + worker)

.PHONY: test-api
test-api: ## Testes da API (pytest)
	cd services/api && pip install -q -r requirements.txt && pytest -q

.PHONY: test-worker
test-worker: ## Vet + build do worker Go
	cd services/worker && go vet ./... && go build ./...

.PHONY: lint
lint: ## Lint de shell scripts e validação de configs
	@command -v shellcheck >/dev/null && shellcheck scripts/*.sh || echo "shellcheck não instalado (opcional)"

.PHONY: tf-validate
tf-validate: ## Valida a configuração Terraform (infra/)
	cd infra && terraform init -backend=false >/dev/null && terraform validate && terraform fmt -check -recursive

## ---------------------------------------------------------------------------
## Operação
## ---------------------------------------------------------------------------

.PHONY: health
health: ## Verifica a saúde dos endpoints da stack
	./scripts/healthcheck.sh

.PHONY: load
load: ## Gera carga manual contra a API (ver scripts/loadtest.sh)
	./scripts/loadtest.sh

.PHONY: help
help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
