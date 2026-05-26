# Alerting

## Rule catalog

| Rule                          | Severity | Group         | Condition (summarized)                                                | Runbook                                                  |
| ----------------------------- | -------- | ------------- | --------------------------------------------------------------------- | -------------------------------------------------------- |
| `HostHighCPU`                 | warning  | host.rules    | Host CPU > 85% for 10m                                                | [§](RUNBOOK.md#hosthighcpu)                              |
| `HostHighMemory`              | warning  | host.rules    | Host memory > 90% for 10m                                             | [§](RUNBOOK.md#hosthighmemory)                           |
| `HostDiskWillFillIn4h`        | warning  | host.rules    | `predict_linear` over 1h crosses 0 within 4h, for 30m                 | [§](RUNBOOK.md#hostdiskwillfillin4h)                     |
| `ContainerRestartingFrequently` | warning | container.rules | Container restarted >2× in 15m                                      | [§](RUNBOOK.md#containerrestartingfrequently)            |
| `ContainerHighMemoryUsage`    | warning  | container.rules | Working-set / limit > 90% for 10m                                     | [§](RUNBOOK.md#containerhighmemoryusage)                 |
| `AppDown`                     | critical | app.rules     | `up{job="app"} == 0` for 2m                                           | [§](RUNBOOK.md#appdown)                                  |
| `AppHighErrorRate`            | critical | app.rules     | 5xx ratio > 5% over 5m                                                | [§](RUNBOOK.md#apphigherrorrate)                         |
| `AppHighLatencyP95`           | warning  | app.rules     | p95 latency > 1s for 10m                                              | [§](RUNBOOK.md#apphighlatencyp95)                        |
| `AppSLOBurnRateFast`          | critical | app.rules     | Multi-window (5m & 1h) burn rate > 14.4× for 2m — see [SLOs.md](SLOs.md) | [§](RUNBOOK.md#appsloburnratefast)                      |
| `PrometheusTargetMissing`     | warning  | app.rules     | `up == 0` for 5m on any job                                           | [§](RUNBOOK.md#prometheustargetmissing)                  |

## Routing

`route` in [alertmanager.yml](../compose/alertmanager/alertmanager.yml):

- All alerts group by `[alertname, severity, job]`.
- `severity=critical` → `webhook-critical` (lower `group_wait`, shorter `repeat_interval`).
- `severity=warning`  → `webhook-default`.

## Inhibition

`AppDown` (critical) inhibits `AppHighErrorRate`, `AppHighLatencyP95`, and `AppSLOBurnRateFast` for the same `job`. Reason: when the app is down, there is no point paging on derivative signals like error rate or latency — they're meaningless if it isn't running, and the operator should focus on bringing it back up.

## Wiring a real receiver

Replace the placeholder `webhook_configs` in [alertmanager.yml](../compose/alertmanager/alertmanager.yml). Shapes (commented in-file):

```yaml
slack_configs:
  - api_url: https://hooks.slack.com/services/REPLACE/ME/PLEASE
    channel: '#alerts-warning'
    send_resolved: true

pagerduty_configs:
  - service_key: REPLACE_ME
    send_resolved: true
```

Never commit a real URL or service key. Use environment variable substitution if you must (Alertmanager supports `${VAR}` in its config since v0.27 with `--enable-feature=expand-env-vars`).

## Triggering an alert for demo / verification

```bash
./scripts/load.sh error 300
```

This curls `/api/error` 300 times in parallel; ~30% return 500, which pushes the 5xx ratio over the 5% threshold. After ~5 minutes:

```bash
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {name: .labels.alertname, state}'
```

`AppHighErrorRate` should be `firing`. Visit Alertmanager at http://localhost:9093 to see grouping + the suppressed/active state.
