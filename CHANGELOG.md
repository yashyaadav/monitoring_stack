# Changelog

All notable changes to this project are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — 2026-05-27

Full rebuild. The pre-1.0 repo was install-instructions-only; 1.0 ships a runnable, instrumented, alert-fireable observability stack.

### Added
- Go sample app (`app/`) with `/api/{fast,slow,error,flaky}` endpoints and full Prometheus instrumentation (request counter, duration histogram, in-flight gauge, build-info).
- Docker Compose stack (`compose/`) with Prometheus 2.55.1, Grafana 11.2.2, Alertmanager 0.27.0, node-exporter 1.8.2, cadvisor 0.49.1, and the sample app — all version-pinned, all with healthchecks.
- Prometheus scrape config + ~10 hand-written alert rules across host, container, and app categories. Includes a multi-window burn-rate SLO alert.
- Alertmanager config with severity-based routing and an `AppDown`-inhibits-everything-else inhibition rule.
- Three hand-built Grafana dashboards provisioned from JSON: app RED, host + containers, Prometheus self-monitoring.
- `scripts/smoke.sh` (asserts Prometheus targets UP, rules loaded, Grafana healthy) and `scripts/load.sh` (traffic generator for firing alerts).
- GitHub Actions `stack-smoke.yml` workflow — boots the full stack on every PR and main push and verifies it end-to-end.
- Kubernetes path (`k8s/`) via `kube-prometheus-stack` Helm chart with custom values and additional `PrometheusRule`.
- Terraform module (`terraform/`) for a one-instance EC2 demo deployment with user-data bootstrap.
- Docs (`docs/`): ARCHITECTURE, INSTALLATION, CONFIGURATION, ALERTING, SLOs, RUNBOOK, TROUBLESHOOTING.
- `Makefile` convenience targets, `LICENSE` (MIT), `CONTRIBUTING.md`, `.editorconfig`, `.dockerignore`, `.env.example`.

### Removed
- Pre-rebuild `README.md` (Helm install transcript) — content folded into `docs/INSTALLATION.md` and `k8s/README.md`.
- `Installation/Prometheus/helm_prometheus.md` and `Installation/Grafana/helm_grafana.md` — duplicates of the old README, superseded.
