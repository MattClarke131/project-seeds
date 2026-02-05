# Kubernetes Workloads

Kubernetes workload configurations for the homelab cluster organized by function.

## Structure
```
kubernetes/
├── ingress/              # Nginx Ingress Controller
│   ├── namespace.yaml
│   ├── values.yaml
│   └── test-ingress.yaml
├── observability/        # Monitoring stack
│   ├── namespace.yaml
│   ├── kube-prometheus-stack/
│   │   └── values.yaml
│   ├── metrics-server/
│   │   └── values.yaml
│   └── dashboards/
│       ├── *.json        # Dashboard source files
│       └── *.yaml        # Generated ConfigMaps
├── storage/             # NFS storage provisioner
│   └── nfs-provisioner.yaml
└── README.md
```

## Prerequisites

Requires a running Talos Kubernetes cluster. See [../proxmox/opentofu/](../proxmox/opentofu/) for cluster provisioning.

## Installation

### 1. Storage
```bash
kubectl apply -f storage/nfs-provisioner.yaml
kubectl get storageclass
```

### 2. Ingress Controller
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  --create-namespace \
  -f ingress/values.yaml
```

### 3. Observability Stack

**Install Prometheus + Grafana:**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl apply -f observability/namespace.yaml

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n observability \
  -f observability/kube-prometheus-stack/values.yaml
```

**Install Metrics Server:**
```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm install metrics-server metrics-server/metrics-server \
  -n observability \
  -f observability/metrics-server/values.yaml
```

**Load Dashboards:**
```bash
kubectl apply -f observability/dashboards/proxmox-overview.yaml
kubectl apply -f observability/dashboards/livio-pods.yaml
```

## Access Points

- **Grafana**: http://10.0.10.2/grafana
- **Cluster API**: https://10.0.10.2:6443

### Grafana Access
```bash
# Get admin password
kubectl get secret -n observability kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Username: admin
```

## Dashboards

Dashboards are managed as ConfigMaps and auto-load into Grafana via sidecar.

### Updating Dashboards
1. Make changes in Grafana UI
2. Export JSON: Dashboard Settings → JSON Model → Copy
3. Overwrite `observability/dashboards/<name>.json`
4. Regenerate ConfigMap:
```bash
kubectl create configmap <name> \
  -n observability \
  --from-file=observability/dashboards/<name>.json \
  --dry-run=client -o yaml > observability/dashboards/<name>.yaml
```
5. Add label to YAML:
```yaml
metadata:
  labels:
    grafana_dashboard: "1"
```
6. Apply: `kubectl apply -f observability/dashboards/<name>.yaml`
7. Commit both JSON and YAML to git

## Quick Commands
```bash
# View all pods
kubectl get pods -A

# Check cluster resources
kubectl top nodes
kubectl top pods -A

# View persistent volumes
kubectl get pvc -A
kubectl get pv

# Check ingress rules
kubectl get ingress -A
```

## Monitoring

Current dashboards:
- **Proxmox Overview** - CPU and memory for physical hosts and VMs
- **Livio Pods** - Pod memory usage on livio nodes

Access via Grafana → Dashboards → Browse
