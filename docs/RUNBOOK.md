# Runbook

One section per alert. Format: symptoms → likely causes → diagnostic commands → remediation → escalation.

> This is a portfolio repo. The "escalation" sections describe what a real on-call rotation would do; here, the answer is usually "open an issue."

---

## AppDown

**Severity:** critical.

### Symptoms

- Prometheus shows `up{job="app"} == 0`.
- Pager from `AppDown`.
- App dashboard panels go blank.

### Likely causes

1. Container crashed (panic, OOM, config error).
2. Container failed health check and was restarted in a crash loop.
3. Compose network or DNS issue (`prometheus` can't resolve `app`).

### Diagnostic commands

```bash
docker compose -f compose/docker-compose.yml ps app
docker compose -f compose/docker-compose.yml logs --tail=200 app
docker compose -f compose/docker-compose.yml exec prometheus wget -qO- http://app:8080/healthz
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="app")'
```

### Remediation

- If crash-looping: read the last 200 log lines for the panic / failed-startup line. Common cause is a port collision; resolve and `docker compose up -d app`.
- If healthy locally but unscrapeable: check `prometheus.yml` scrape job hostname matches the Compose service name (`app`, not `localhost`).

### Escalation

In a real deployment: page primary on-call; if mitigation > 15m, page secondary and incident commander.

---

## AppHighErrorRate

**Severity:** critical.

### Symptoms

- 5xx ratio > 5% over the last 5m.
- App RED dashboard "Error rate" panel red.

### Likely causes

1. A bad deploy returning 5xx for a subset of routes.
2. A downstream dependency failing (database, cache, third-party API).
3. Resource exhaustion (OOM, file descriptors).

### Diagnostic commands

```promql
# Top routes by error rate
topk(5, sum by (route) (rate(http_requests_total{job="app",code=~"5.."}[5m])))

# Error rate split by status code
sum by (code) (rate(http_requests_total{job="app",code=~"5.."}[5m]))
```

```bash
docker compose -f compose/docker-compose.yml logs --tail=500 app | grep -iE 'error|panic|fatal'
```

### Remediation

- Recent deploy → roll back.
- Single route hot → isolate; if it's a known degradation, silence the alert with a duration matching the rollout/fix window via Alertmanager.
- Dependency failure → check downstream dashboards; reduce traffic or fail open if applicable.

### Escalation

If error budget burn is fast (see [AppSLOBurnRateFast](#appsloburnratefast)), escalate immediately — budget exhaustion in <2 days is a paging-grade event.

---

## AppHighLatencyP95

**Severity:** warning.

### Symptoms

- p95 latency > 1s for 10m.
- App RED dashboard latency panel showing p95 above threshold.

### Likely causes

1. Increased load on the slow endpoint (`/api/slow` will produce this if hit heavily).
2. Garbage collection pressure / blocked goroutines.
3. Downstream dependency latency.

### Diagnostic commands

```promql
# Per-route p95
histogram_quantile(0.95,
  sum by (le, route) (rate(http_request_duration_seconds_bucket{job="app"}[5m]))
)
```

### Remediation

- If concentrated on one route: identify the slowdown (profile, log inspection). For this demo app, expected on `/api/slow`.
- If broad: capacity issue — scale horizontally or reduce load.

### Escalation

If latency is sustained and tied to user-facing impact: open an incident. For this demo: usually self-resolves when traffic drops.

---

## AppSLOBurnRateFast

**Severity:** critical.

### Symptoms

- Multi-window burn rate over 14.4× the SLO error rate for 2m (5m AND 1h windows both breaching).
- At this pace, the 28-day error budget is exhausted within ~2 days.

### Likely causes

Same as [AppHighErrorRate](#apphigherrorrate) but qualified — a sustained burn means it's not just a transient spike.

### Diagnostic commands

See [AppHighErrorRate](#apphigherrorrate). Additionally:

```promql
# Budget remaining (rough): 1 - error_rate / (1 - SLO)
1 - (
  sum(rate(http_requests_total{job="app",code=~"5.."}[28d]))
    / sum(rate(http_requests_total{job="app"}[28d]))
) / 0.01
```

### Remediation

Stop the bleed first. If a rollback is available, ship it. If not, reduce blast radius (feature flag, traffic shedding, partial rollback). Backfilling the error budget after the fact is not possible — only the next 28d window resets the clock.

### Escalation

Treat as a real incident: declare, assign IC, communicate status. See your org's incident process.

---

## PrometheusTargetMissing

**Severity:** warning.

### Symptoms

- `up == 0` for any job for 5m.

### Likely causes

1. Service stopped (most common — covered by service-specific alerts like `AppDown`).
2. Service moved IPs / hostnames (Compose: rare; K8s: normal during rollouts — Prometheus Operator handles this via `ServiceMonitor`).
3. Scrape config out of date.

### Diagnostic commands

```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health=="down") | {job: .labels.job, lastError}'
docker compose -f compose/docker-compose.yml ps
```

### Remediation

- Service down → restart, follow service-specific runbook entry.
- Config drift → update [prometheus.yml](../compose/prometheus/prometheus.yml) scrape job, reload with `curl -X POST http://localhost:9090/-/reload`.

---

## HostHighCPU

**Severity:** warning.

### Symptoms

- Host CPU > 85% for 10m.

### Likely causes

1. A noisy neighbor container.
2. A scheduled job (cron, batch) saturating cores.
3. An infinite loop in user code.

### Diagnostic commands

```promql
# Per-CPU breakdown
avg by (cpu) (rate(node_cpu_seconds_total{mode!="idle"}[1m]))
# Per-container CPU (correlates host pressure to a specific container)
topk(5, sum by (name) (rate(container_cpu_usage_seconds_total{name!=""}[1m])))
```

### Remediation

- Identify the offender via the host & containers dashboard.
- Set a container CPU limit (`deploy.resources.limits.cpus` in Compose, or a Pod spec field in K8s).

---

## HostHighMemory

**Severity:** warning.

### Symptoms

- Available memory below 10% for 10m.

### Likely causes

1. Container leak.
2. Steady growth in TSDB or Grafana cache.
3. Host running other workloads in parallel.

### Diagnostic commands

```promql
topk(5, sum by (name) (container_memory_working_set_bytes{name!=""}))
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes
```

### Remediation

- Identify the largest containers; cap their memory.
- For Prometheus specifically: lower retention, drop high-cardinality labels.

---

## HostDiskWillFillIn4h

**Severity:** warning.

### Symptoms

- Linear projection of `node_filesystem_avail_bytes` crosses zero within 4h, for 30m.

### Likely causes

1. Prometheus TSDB growth.
2. Container logs filling `/var/lib/docker`.
3. Application data growth.

### Diagnostic commands

```bash
docker system df
du -sh /var/lib/docker/containers/* 2>/dev/null | sort -h | tail -10
```

### Remediation

- Rotate / truncate container logs: `docker compose down && docker compose up -d` after configuring `logging.options.max-size` per service.
- Prometheus disk: drop retention temporarily (`--storage.tsdb.retention.time=2d`) and reload.

---

## ContainerRestartingFrequently

**Severity:** warning.

### Symptoms

- A container restarted more than twice in 15m.

### Likely causes

1. Bad config (the container fails its healthcheck or exits non-zero on startup).
2. OOMKill loop.
3. Failing dependency that the entrypoint exits on.

### Diagnostic commands

```bash
docker inspect --format '{{.RestartCount}} {{.State.Status}} {{.State.OOMKilled}} {{.State.Error}}' <container-id>
docker compose -f compose/docker-compose.yml logs --tail=200 <service>
```

### Remediation

- OOM → raise the memory limit or fix the leak.
- Bad config → fix and redeploy.
- Dependency → fix dependency or relax the entrypoint's exit condition.

---

## ContainerHighMemoryUsage

**Severity:** warning.

### Symptoms

- Working-set memory > 90% of the configured container limit for 10m.

### Likely causes

1. Limit set too tight for actual workload.
2. Memory leak.

### Diagnostic commands

```promql
container_memory_working_set_bytes{name="<service>"} / container_spec_memory_limit_bytes{name="<service>"}
```

### Remediation

- Raise the limit *or* fix the leak — don't just raise the limit forever.
- Confirm the limit is intentional (Compose with `deploy.resources.limits.memory`).
