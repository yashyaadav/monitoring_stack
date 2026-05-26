COMPOSE        ?= docker compose -f compose/docker-compose.yml
PROM_IMAGE     ?= prom/prometheus:v2.55.1
AM_IMAGE       ?= prom/alertmanager:v0.27.0
YAMLLINT_IMAGE ?= cytopia/yamllint:1
HADOLINT_IMAGE ?= hadolint/hadolint:v2.12.0

.DEFAULT_GOAL := help

.PHONY: help
help:
	@awk 'BEGIN { FS = ":.*##"; print "Targets:" } /^[a-zA-Z0-9_-]+:.*##/ { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: up
up: ## Start the stack and wait for healthy
	$(COMPOSE) up -d --wait

.PHONY: down
down: ## Stop the stack and remove volumes
	$(COMPOSE) down -v

.PHONY: logs
logs: ## Tail logs
	$(COMPOSE) logs -f

.PHONY: ps
ps: ## Show service status
	$(COMPOSE) ps

.PHONY: smoke
smoke: ## Run end-to-end smoke checks against a running stack
	./scripts/smoke.sh

.PHONY: load-error
load-error: ## Generate error traffic to fire AppHighErrorRate
	./scripts/load.sh error 300

.PHONY: load-mixed
load-mixed: ## Generate mixed traffic to populate dashboards
	./scripts/load.sh mixed 1000 16

.PHONY: test
test: ## Run Go tests for the sample app
	cd app && go mod tidy && go test -race -cover ./...

.PHONY: lint
lint: lint-yaml lint-prom lint-am lint-docker ## Run all linters

.PHONY: lint-yaml
lint-yaml:
	docker run --rm -v "$(PWD):/data" $(YAMLLINT_IMAGE) -d "{extends: relaxed, rules: {line-length: disable}}" compose/ .github/

.PHONY: lint-prom
lint-prom:
	docker run --rm -v "$(PWD)/compose/prometheus:/etc/prometheus:ro" --entrypoint promtool $(PROM_IMAGE) check config /etc/prometheus/prometheus.yml
	docker run --rm -v "$(PWD)/compose/prometheus:/etc/prometheus:ro" --entrypoint promtool $(PROM_IMAGE) check rules /etc/prometheus/alerts/host.rules.yml /etc/prometheus/alerts/container.rules.yml /etc/prometheus/alerts/app.rules.yml

.PHONY: lint-am
lint-am:
	docker run --rm -v "$(PWD)/compose/alertmanager:/etc/alertmanager:ro" --entrypoint amtool $(AM_IMAGE) check-config /etc/alertmanager/alertmanager.yml

.PHONY: lint-docker
lint-docker:
	docker run --rm -i $(HADOLINT_IMAGE) < app/Dockerfile

.PHONY: tf-init
tf-init: ## terraform init
	cd terraform && terraform init

.PHONY: tf-plan
tf-plan: ## terraform plan (requires -var key_name=... -var repo_url=...)
	cd terraform && terraform plan
