# Observability

## Prometheus
### 1. Update prometheus variables to match terraform environment
```bash
./sync-prometheus-targets.sh
```
### 2. Apply prometheus configuration
```bash
./apply-prometheus-config.sh
```

### 3. Upgrade Prometheus with new values.yaml
```bash
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -f kube-prometheus-stack/values.yaml \
  -n observability
```
