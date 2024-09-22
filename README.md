
# Prometheus and Grafana Setup on Minikube (Local and EC2 Instance)

## Installing Helm

```bash
# To install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

## Creating a namespace monitoring in the kubernetes cluster
```bash
# Create a namespace monitoring 
kubectl create namespace monitoring
```

## Adding Helm Repo for Prometheus
```bash
# Add helm chart for prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update the repo
helm repo update
```

## Installing Prometheus

```bash
# Installing prometheus in monitoring namespace
helm install prometheus prometheus-community/prometheus --namespace monitoring
```

### Exposing Prometheus Service

```bash
# Expose prometheus service (would change type from cluster IP to node port and create a new service)
kubectl expose service prometheus-server --namespace=monitoring --type=NodePort --target-port=9090 --name=prometheus-server-ext

# To get minikube IP for Kubernetes cluster
minikube ip

# To check if the prometheus is running
# From the minikube cluster
http://<minikube-IP>:<port_no_of_exposed_prom_service>
# For example
http://192.168.49.2:31000/
```

### Accessing Prometheus from Local Machine (if minikube cluster on EC2 Instance)

```bash
# To access prometheus server from local machine from the minikube cluster on EC2 instance, use port forwarding
ssh -i "your_ec2_key.pem" -L 9090:192.168.49.2:31000 ubuntu@your_ec2_public_ip

# Access Prometheus UI from local browser
http://localhost:9090
```

## Installing Grafana

```bash
# Add helm repo for grafana
helm repo add grafana https://grafana.github.io/helm-charts

# Update the helm repo
helm repo update

# Install grafana in the monitoring namespace
helm install grafana grafana/grafana --namespace monitoring
```

### Exposing Grafana Service

```bash
# Expose Grafana service
kubectl expose service grafana --type=NodePort --target-port=3000 --name=grafana-ext -n monitoring

# Access grafana from minikube host
http://<minikube_ip>:<grafana_service_port>
```

### Accessing Grafana from Local Machine

```bash
# To access grafana from local machine (if minikube on EC2), use port forwarding from EC2 instance to local machine

ssh -i "daily_aws_key.pem" -L 3000:192.168.49.2:32592 ubuntu@34.212.146.169

# For Accessing both Prometheus and Grafana
ssh -i "daily_aws_key.pem" -L 9090:192.168.49.2:31000 -L 3000:192.168.49.2:32592 ubuntu@34.212.146.169

# Access Grafana UI (from local browser)
http://localhost:3000
```

## Configuring Prometheus as a Data Source in Grafana

```bash
# Prometheus URL
http://<minikube_ip>:<prometheus_service_port>
http://192.168.49.2:31000
```

### Importing Dashboards

```bash
# Create dashboards in Grafana using import (Dashboard ID: 3662 for Prometheus 2.0 Overview)
```

## Exposing kube-state-metrics in Prometheus

```bash
# Expose prometheus-kube-state-metrics service in monitoring namespace
kubectl expose service prometheus-kube-state-metrics --type=NodePort --target-port=8080 --name=prometheus-kube-state-metrics-ext -n monitoring

# To access prometheus-kube-state-metrics-ext service
http://<minikube_ip>:<service_port>

# Since using port forwarding, access via:
http://localhost:8080/metrics
```

### Accessing kube-state-metrics from Local Machine

```bash
ssh -i "daily_aws_key.pem" -L 9090:192.168.49.2:31000 -L 3000:192.168.49.2:32592 -L 8080:192.168.49.2:30558 ubuntu@34.212.146.169

# Port forwarding explanation (on local browser):
# - 9090: Prometheus
# - 3000: Grafana
# - 8080: kube-state-metrics
```

## Configuring Prometheus to Scrape kube-state-metrics

```bash
# Add scraping job for kube-state-metrics in prometheus-server config map
# Target URL: http://<minikube_ip>:<service_port>
# Since using port forwarding, target URL: http://localhost:8080

# To get and edit config maps
kubectl get cm
kubectl edit cm <config_map_name> -n monitoring
# For example
kubectl edit cm prometheus-server -n monitoring

# This job is for scraping kube-state-metrics
- job_name: state_metrics
  static_configs:
  - targets:
    - localhost:8080 # It would be minikube_ip:node_port if we are running minikube on local machine and not the EC2 Instance

# After editing the config map, do a rollout restart
kubectl rollout restart deployment prometheus-server -n monitoring
```