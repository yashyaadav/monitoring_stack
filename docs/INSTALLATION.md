# Installation

Three paths, in order of fastest review experience to most realistic deployment.

## 1. Docker Compose (local, ~30 seconds)

Default path. Requires Docker Desktop / Docker Engine + Compose plugin.

```bash
git clone https://github.com/yashyaadav/monitoring_stack.git
cd monitoring_stack
cp .env.example .env             # edit GF_SECURITY_ADMIN_PASSWORD if you like
make up                          # docker compose -f compose/docker-compose.yml up -d --wait
make smoke                       # asserts targets UP, rules loaded, Grafana healthy
```

Visit:

| URL                           | What it is                |
| ----------------------------- | ------------------------- |
| http://localhost:3000         | Grafana (admin/admin)     |
| http://localhost:9090         | Prometheus                |
| http://localhost:9093         | Alertmanager              |
| http://localhost:8080/metrics | Sample app metrics        |

Teardown: `make down` (also removes volumes).

## 2. Kubernetes (Helm via kube-prometheus-stack)

See [k8s/README.md](../k8s/README.md). One-liner:

```bash
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  -n monitoring -f k8s/values-kube-prometheus-stack.yaml
```

This installs Prometheus + Grafana + Alertmanager + node-exporter + kube-state-metrics as a single managed bundle, with our custom values applied (retention, app `ServiceMonitor`, dashboards via sidecar). The custom `PrometheusRule` for the sample app lives at [k8s/extra-alerts/app.rules.yml](../k8s/extra-alerts/app.rules.yml).

Access the UIs via `kubectl port-forward`:

```bash
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-alertmanager 9093
```

Grafana admin password (default `prom-operator`): override via `--set grafana.adminPassword=...` or a Kubernetes secret. Do not commit a real password.

## 3. AWS EC2 (Terraform)

Single-instance demo. Useful for sharing a public URL with a reviewer. **Not production — no remote backend, no multi-AZ, security group default is `0.0.0.0/0`.**

See [terraform/README.md](../terraform/README.md). One-liner:

```bash
cd terraform
terraform init
terraform apply \
  -var key_name=your-ec2-keypair \
  -var repo_url=https://github.com/yashyaadav/monitoring_stack.git \
  -var allowed_cidr=$(curl -s ifconfig.me)/32
```

`user_data.sh` installs Docker + Compose plugin, clones the repo, and runs `docker compose up -d`. Outputs include the public Grafana URL.

Teardown: `terraform destroy`.
