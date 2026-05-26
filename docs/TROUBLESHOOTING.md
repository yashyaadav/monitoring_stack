# Troubleshooting

Problems you're likely to hit running this stack locally, with fast diagnostic commands.

## Prometheus targets are DOWN

Prometheus shows one or more jobs as `DOWN` at http://localhost:9090/targets.

```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health, lastError}'
docker compose -f compose/docker-compose.yml ps
docker compose -f compose/docker-compose.yml logs --tail=200 <service>
```

Common causes:

- The target service hasn't started yet — wait 15s and re-check.
- Scrape hostname is wrong. Compose service names (`app`, `node-exporter`, `cadvisor`, `alertmanager`) are the DNS names Prometheus must use, not `localhost`.
- Port mismatch — `app:8080`, `prometheus:9090`, `alertmanager:9093`, `node-exporter:9100`, `cadvisor:8080`.

## Grafana shows "No data" on every panel

The datasource isn't reaching Prometheus, or Prometheus has no data yet.

```bash
docker compose -f compose/docker-compose.yml exec grafana wget -qO- http://prometheus:9090/-/ready
curl -s http://localhost:9090/api/v1/query?query=up | jq
```

If Prometheus is up and returning data but Grafana shows nothing: re-check that the provisioned datasource UID (`prometheus`) matches the UID referenced inside the dashboard JSON. Dashboards in this repo all use `"uid": "prometheus"` consistent with [datasources/prometheus.yml](../compose/grafana/provisioning/datasources/prometheus.yml).

## Alerts aren't firing even though traffic looks bad

```bash
# Is the rule even loaded?
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | {name: .name, state: .state}'

# Did Alertmanager receive anything?
curl -s http://localhost:9093/api/v2/alerts | jq
```

Two common reasons:

- The `for:` clause hasn't been satisfied yet — `AppHighErrorRate` requires 5 minutes of sustained breach.
- The rule expression returns 0/empty — paste it into the Prometheus UI's expression browser and verify the value is non-empty and above threshold.

## cadvisor doesn't show containers on macOS / Docker Desktop

cadvisor mounts the host filesystem and reads cgroup data. On Docker Desktop, this works but metrics may be incomplete (no per-cgroup memory limits) because Docker Desktop runs Linux in a VM. This is a Docker Desktop quirk, not a bug in this stack.

Workaround for full fidelity: run on a Linux host or in CI.

## Sample app container is "(unhealthy)" but `/healthz` returns 200

The Docker `HEALTHCHECK` runs `/sample-app healthcheck`. If the binary exits non-zero, the container is marked unhealthy. Check what the healthcheck logs say:

```bash
docker inspect ms-app --format '{{json .State.Health}}' | jq
```

If `/healthz` returns 200 from `curl http://localhost:8080/healthz` on the host but the healthcheck fails, the container can't reach itself on `127.0.0.1:8080` — verify `APP_PORT` matches what the server binds to.

## `make up` says "port is already allocated"

Another process owns the port. Identify and stop:

```bash
lsof -nP -i :3000   # Grafana
lsof -nP -i :9090   # Prometheus
lsof -nP -i :9093   # Alertmanager
lsof -nP -i :8080   # App + cAdvisor (both want 8080 in their containers — host port is for the app only)
```

If you have another local Grafana/Prometheus running, stop it first.

## "go.sum missing" when running `make test`

First-time setup needs `go mod tidy` to materialize `go.sum`:

```bash
cd app && go mod tidy && cd ..
make test
```

The `make test` target already runs `go mod tidy` for you.
