# SLOs

A single illustrative SLO so the alert catalog has a real burn-rate rule pointed at something concrete.

## The SLO

> **99% of requests to the sample app return non-5xx, measured over a rolling 28-day window.**

- **SLI:** `1 - (sum(rate(http_requests_total{job="app",code=~"5.."}[28d])) / sum(rate(http_requests_total{job="app"}[28d])))`.
- **Objective:** 0.99.
- **Error budget:** 1% — about 7 hours of total errored requests per 28 days (proportional, not consecutive).

## Multi-window multi-burn-rate alert

A "fast burn" alert that pages when the app would exhaust its 28-day error budget in roughly 2 days at the current rate. Follows the Google SRE workbook pattern: two windows (a long one for accuracy, a short one for responsiveness) both have to exceed the threshold simultaneously, which suppresses flaps and short spikes.

For a 99% SLO, **fast burn** = 14.4 × (1 − SLO) = 14.4 × 0.01 = 0.144 (i.e., a 14.4% error rate).

Implemented in [`compose/prometheus/alerts/app.rules.yml`](../compose/prometheus/alerts/app.rules.yml) as `AppSLOBurnRateFast`:

```promql
(
  sum(rate(http_requests_total{job="app",code=~"5.."}[5m]))
    / sum(rate(http_requests_total{job="app"}[5m]))
) > (14.4 * 0.01)
and
(
  sum(rate(http_requests_total{job="app",code=~"5.."}[1h]))
    / sum(rate(http_requests_total{job="app"}[1h]))
) > (14.4 * 0.01)
```

Both the 5-minute and 1-hour windows must agree. The `for: 2m` prevents short transient breaches from paging.

## What's intentionally missing

- **A latency SLO.** A second SLO (e.g., "99% of requests under 500ms") would mirror the same pattern against the duration histogram. Skipped to keep the rule catalog small and the runbook focused — the latency *threshold* alert (`AppHighLatencyP95`) covers the operational case without the budget-accounting machinery.
- **A "slow burn" companion alert** (24h/3d windows). The Google workbook recommends pairing fast and slow burn for full coverage. Not added here because at 99% with synthetic traffic, the slow-burn signal mostly just duplicates the threshold alerts. Worth adding for a real service.
- **Recording rules to pre-compute the SLI.** At this scale Prometheus evaluates the burn-rate expressions cheaply. For a service with high cardinality or aggregations over many labels, you'd materialize `slo:errors:ratio_rate_5m`, `_1h`, `_24h` etc. as recording rules and write the alert against those — both for cost and for consistency with dashboard panels.
