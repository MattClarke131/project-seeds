# Observability

## Components
- **Prometheus**: Metrics collection and storage
- **Grafana**: Dashboards and visualization
- **Metrics Server**: Resource metrics (kubectl top)
- **Loki**: Log aggregation and storage
- **Promtail**: Log collection agent

## Initial Setup

### Prometheus

`kube-prometheus-stack` is Flux-managed (`kube-prometheus-stack/helmrelease.yaml`,
see [../../../clusters/eye-of-michael/README.md](../../../clusters/eye-of-michael/README.md))
- editing `helmrelease.yaml`'s `spec.values` and merging to `main` is the
deploy step; there's no `helm upgrade` to run by hand any more.

Scrape targets still need regenerating locally when the Terraform node
inventory changes, since that step reads live `tofu output`, then commit
the result for Flux to pick up:
```bash
./sync-prometheus-targets.sh
./apply-prometheus-config.sh
git add kube-prometheus-stack/prometheus-targets-configmap.yaml
git commit
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
