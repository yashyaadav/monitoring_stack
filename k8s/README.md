# Kubernetes path — kube-prometheus-stack

This directory holds the Helm values and extra CRs needed to run the same stack on Kubernetes that [compose/](../compose/) runs locally. We layer on top of the community `kube-prometheus-stack` chart rather than installing Prometheus + Grafana + Alertmanager as separate charts — that's the modern default and gives you the Prometheus Operator + ServiceMonitor pattern for free.

## What you get

- Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics, all wired together by the operator.
- The default kube-prometheus-stack alert rules (cluster, node, etcd*, etc.).
- Our app-specific alert rules from [extra-alerts/app.rules.yml](extra-alerts/app.rules.yml), mirroring the Compose path.
- The same severity-based routing and `AppDown` inhibition rule as the Compose Alertmanager, applied via the chart's inline `alertmanager.config`.

\* Some etcd rules are disabled in the values file because a demo cluster (kind/minikube/EKS without control-plane scrape) won't have those metrics.

## Install

```bash
kubectl create namespace monitoring

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values-kube-prometheus-stack.yaml \
  --set grafana.adminPassword="$(openssl rand -hex 12)"

kubectl -n monitoring apply -f extra-alerts/app.rules.yml
```

The `--set grafana.adminPassword` override is critical — never use the chart default in any environment reachable from outside your laptop.

## Deploy the sample app

A bare-minimum Deployment + Service + ServiceMonitor for the sample app (the same image built by [../app/Dockerfile](../app/Dockerfile)):

```yaml
# sample-app.yaml — apply with kubectl -n monitoring apply -f
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  labels: { app: app }
spec:
  replicas: 2
  selector: { matchLabels: { app: app } }
  template:
    metadata:
      labels: { app: app }
    spec:
      containers:
        - name: app
          image: ghcr.io/yashyaadav/monitoring_stack/sample-app:v1.0.0
          ports: [{ containerPort: 8080, name: http }]
          readinessProbe:
            httpGet: { path: /readyz, port: 8080 }
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
---
apiVersion: v1
kind: Service
metadata:
  name: app
  labels: { app: app }
spec:
  selector: { app: app }
  ports: [{ name: http, port: 8080, targetPort: 8080 }]
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: app
  labels: { release: kps }
spec:
  selector: { matchLabels: { app: app } }
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

The `release: kps` label is what the operator looks for; the default `serviceMonitorSelectorNilUsesHelmValues: false` in our values file makes the operator pick up any `ServiceMonitor` regardless of label, but keeping the label is good hygiene.

## Access the UIs

```bash
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-alertmanager 9093
```

Grafana initial username: `admin`. Password: whatever you passed via `--set grafana.adminPassword`.

## Uninstall

```bash
kubectl -n monitoring delete -f extra-alerts/app.rules.yml
helm uninstall kps -n monitoring
kubectl delete namespace monitoring   # CRDs created by the chart are kept by Helm by default; this is fine
```

## What's intentionally not here

- **No multi-cluster federation, Thanos, or remote-write.** Out of scope.
- **No Loki/Tempo.** Metrics only; see the [root README](../README.md#what-id-add-next) for what would extend this.
- **No ingress / TLS for Grafana.** A real deployment fronts Grafana with an ingress + TLS + auth proxy. For a portfolio demo, `port-forward` is honest.
