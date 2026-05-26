#!/usr/bin/env bash
# Generate traffic against the sample app to populate dashboards or fire alerts.
#
# Usage:
#   ./scripts/load.sh <endpoint> [count] [concurrency]
#
#   endpoint    one of: fast | slow | error | flaky | mixed
#   count       total requests (default 200)
#   concurrency parallel workers (default 8)
#
# Examples:
#   ./scripts/load.sh fast 500
#   ./scripts/load.sh error 300         # fires AppHighErrorRate after ~5m
#   ./scripts/load.sh mixed 1000 16
set -euo pipefail

endpoint="${1:-fast}"
count="${2:-200}"
concurrency="${3:-8}"
base="${APP_URL:-http://localhost:8080}"

case "$endpoint" in
  fast|slow|error|flaky) path="/api/$endpoint" ;;
  mixed) path="MIXED" ;;
  *) echo "unknown endpoint: $endpoint" >&2; exit 2 ;;
esac

pick_mixed() {
  local r=$((RANDOM % 10))
  case $r in
    0|1|2|3|4|5) echo "/api/fast" ;;
    6|7) echo "/api/slow" ;;
    8) echo "/api/error" ;;
    9) echo "/api/flaky" ;;
  esac
}

do_one() {
  local p="$1"
  curl -s -o /dev/null -w "%{http_code}\n" "$base$p" || true
}

echo "load: $count requests to $endpoint at concurrency $concurrency"
seq 1 "$count" | xargs -P "$concurrency" -I{} bash -c '
  base="'"$base"'"
  path="'"$path"'"
  if [[ "$path" == "MIXED" ]]; then
    r=$((RANDOM % 10))
    case $r in
      0|1|2|3|4|5) p="/api/fast" ;;
      6|7) p="/api/slow" ;;
      8) p="/api/error" ;;
      9) p="/api/flaky" ;;
    esac
  else
    p="$path"
  fi
  curl -s -o /dev/null -w "%{http_code} " "$base$p" || true
' >/dev/null

echo "done"
