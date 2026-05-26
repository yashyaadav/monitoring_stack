# Configuration

Pointer table: "I want to change X" → file (and line if stable).

| I want to change…                            | Edit                                                                            |
| -------------------------------------------- | ------------------------------------------------------------------------------- |
| Grafana admin user / password                | [.env](../.env.example) → `GF_SECURITY_ADMIN_{USER,PASSWORD}`                   |
| Prometheus scrape interval (global)          | [compose/prometheus/prometheus.yml](../compose/prometheus/prometheus.yml) → `global.scrape_interval` |
| Prometheus retention                         | [compose/docker-compose.yml](../compose/docker-compose.yml) → `--storage.tsdb.retention.time` flag (default `7d`) |
| Add a scrape target                          | [compose/prometheus/prometheus.yml](../compose/prometheus/prometheus.yml) → new entry under `scrape_configs` |
| Tune an alert threshold                      | [compose/prometheus/alerts/*.rules.yml](../compose/prometheus/alerts/)          |
| Add a new alert rule                         | Add to the right `*.rules.yml`, then add a runbook entry to [RUNBOOK.md](RUNBOOK.md) (PR will be asked to add it otherwise) |
| Change alert routing / receivers             | [compose/alertmanager/alertmanager.yml](../compose/alertmanager/alertmanager.yml) → `route` and `receivers` |
| Wire a real Slack/PagerDuty                  | Replace the commented `slack_configs` / `pagerduty_configs` stubs in `alertmanager.yml` |
| Add or modify a Grafana dashboard            | [compose/grafana/provisioning/dashboards/json/](../compose/grafana/provisioning/dashboards/json/) — edit the JSON, restart Grafana (or wait `updateIntervalSeconds`) |
| Disable a dashboard                          | Delete or move its JSON file                                                    |
| Change app port                              | [compose/docker-compose.yml](../compose/docker-compose.yml) → `services.app.ports` + Prometheus scrape job |
| Change Compose image versions                | [compose/docker-compose.yml](../compose/docker-compose.yml) — never `:latest`   |
| K8s analogues (chart values, ServiceMonitor) | [k8s/values-kube-prometheus-stack.yaml](../k8s/values-kube-prometheus-stack.yaml) |
| Terraform variables (region, instance type)  | [terraform/variables.tf](../terraform/variables.tf)                             |

## After editing alert rules

Compose stack:

```bash
make lint-prom                                              # promtool validates rules
curl -fsS -X POST http://localhost:9090/-/reload            # hot reload Prometheus
```

Kubernetes: the Prometheus Operator reloads automatically when the `PrometheusRule` CR changes.

## After editing the Alertmanager config

```bash
make lint-am
curl -fsS -X POST http://localhost:9093/-/reload
```
