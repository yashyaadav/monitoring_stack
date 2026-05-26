#!/usr/bin/env bash
# Smoke test: assumes `docker compose up -d --wait` is already done.
# Verifies the stack is functional end-to-end.
set -euo pipefail

PROM_URL="${PROM_URL:-http://localhost:9090}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
APP_URL="${APP_URL:-http://localhost:8080}"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
step()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

step "app: /healthz returns 200"
curl -fsS "$APP_URL/healthz" >/dev/null
green "ok"

step "app: send probe traffic to populate Vec metric families"
# *Vec metrics in client_golang only emit at /metrics after the first observation.
for _ in 1 2 3; do curl -fsS "$APP_URL/api/fast" >/dev/null; done
green "ok"

step "app: /metrics exposes expected families"
metrics=$(curl -fsS "$APP_URL/metrics")
for fam in http_requests_total http_request_duration_seconds http_in_flight_requests app_build_info; do
  if ! grep -q "^# HELP $fam " <<<"$metrics"; then
    red "missing metric family: $fam"
    exit 1
  fi
done
green "ok"

step "prometheus: all active targets are UP"
targets=$(curl -fsS "$PROM_URL/api/v1/targets")
down=$(jq -r '[.data.activeTargets[] | select(.health != "up") | .labels.job] | join(",")' <<<"$targets")
if [[ -n "$down" ]]; then
  red "targets not UP: $down"
  jq '.data.activeTargets[] | {job: .labels.job, health, lastError}' <<<"$targets"
  exit 1
fi
green "ok"

step "prometheus: rule groups loaded"
groups=$(curl -fsS "$PROM_URL/api/v1/rules" | jq '.data.groups | length')
if (( groups < 3 )); then
  red "expected >=3 rule groups, got $groups"
  exit 1
fi
green "ok ($groups groups)"

step "grafana: /api/health reports database ok"
health=$(curl -fsS "$GRAFANA_URL/api/health")
if ! jq -e '.database == "ok"' >/dev/null <<<"$health"; then
  red "grafana not healthy: $health"
  exit 1
fi
green "ok"

step "alertmanager: /-/ready returns 200"
curl -fsS "${AM_URL:-http://localhost:9093}/-/ready" >/dev/null
green "ok"

echo
green "smoke: all checks passed"
