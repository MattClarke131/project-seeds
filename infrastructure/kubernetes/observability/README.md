# Observability

## Components
- **Prometheus**: Metrics collection and storage
- **Grafana**: Dashboards and visualization
- **Metrics Server**: Resource metrics (kubectl top)
- **Loki**: Log aggregation and storage
- **Promtail**: Log collection agent

## Initial Setup

### Prometheus
1. Update prometheus variables to match terraform environment
```bash
./sync-prometheus-targets.sh
```

2. Apply prometheus configuration
```bash
./apply-prometheus-config.sh
```

3. Upgrade Prometheus with new values.yaml
```bash
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -f kube-prometheus-stack/values.yaml \
  -n observability
```

### Loki + Promtail
1. Install Loki
```bash
cd loki
helm install loki grafana/loki \
  --namespace observability \
  --values values.yaml
```

2. Install Promtail
```bash
helm install promtail grafana/promtail \
  --namespace observability \
  --set "config.clients[0].url=http://loki-gateway.observability.svc.cluster.local/loki/api/v1/push"
```

3. Add Loki datasource to Grafana
   - URL: `http://loki-gateway.observability.svc.cluster.local`
   - Configuration → Data Sources → Add Loki

## Accessing Grafana

Get the admin password:
```bash
kubectl get secret -n observability kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```
