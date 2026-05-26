# Contributing

Thanks for the interest. This is a portfolio repo, not a production project, but contributions that improve clarity, correctness, or coverage are welcome.

## Local development

```bash
cp .env.example .env
make up           # docker compose up -d --wait
make smoke        # run scripts/smoke.sh against the running stack
make load-error   # generate traffic to fire AppHighErrorRate
make down         # tear down + remove volumes
```

## Before opening a PR

Run locally (CI only runs the smoke test):

```bash
make lint   # yamllint + promtool check rules + amtool check-config + hadolint
make test   # go test -race -cover ./app/...
make smoke  # full end-to-end against a running stack
```

## Adding a new alert rule

Every new rule must ship with:

1. The rule itself in `compose/prometheus/alerts/*.rules.yml` (and the equivalent `PrometheusRule` entry in `k8s/extra-alerts/` if app-specific).
2. `severity` label and `summary` + `description` + `runbook_url` annotations.
3. A corresponding section in [docs/RUNBOOK.md](docs/RUNBOOK.md) — symptoms, likely causes, diagnostic commands, remediation.
4. A panel on the relevant Grafana dashboard if the metric isn't already visualized.

PRs that add rules without runbook entries will be asked to add them.

## Style

- YAML: 2-space indent, no trailing whitespace (enforced by `.editorconfig` + `yamllint`).
- Go: `gofmt`, `go vet`.
- Shell: `shellcheck`-clean.
- Image tags: never `:latest`. Pin a version.
