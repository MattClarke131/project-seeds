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

### Metrics Server

`metrics-server` is Flux-managed (`metrics-server/helmrelease.yaml`) -
editing `helmrelease.yaml`'s `spec.values` and merging to `main` is the
deploy step; there's no `helm upgrade` to run by hand any more.

### Loki + Promtail

Both are Flux-managed (`loki/helmrelease.yaml`, `promtail/helmrelease.yaml`)
- editing `helmrelease.yaml`'s `spec.values` and merging to `main` is the
deploy step; there's no `helm upgrade` to run by hand any more.
`loki/values.yaml` is kept as a standalone reference copy of the same
values, not wired in.

Add Loki datasource to Grafana:
- URL: `http://loki-gateway.observability.svc.cluster.local`
- Configuration → Data Sources → Add Loki

## Dashboards

Dashboard JSON lives in `dashboards/*.yaml` as ConfigMaps labeled
`grafana_dashboard: "1"`; a sidecar in the Grafana pod watches for that
label and loads/reloads dashboards automatically. Flux manages these
files like everything else in this tree - merging to `main` is the
deploy step.

### Testing a dashboard change before merging

Flux reconciles this whole directory, so a `kubectl apply` of a
committed dashboard's ConfigMap gets reverted back to whatever's on
`main` on Flux's next sync (harmless, but your test edits vanish
without warning). The sidecar itself doesn't care who applied a
ConfigMap or whether it's in git though - it just watches for the
label. So test under a ConfigMap **Flux doesn't own**, by giving it a
name that isn't committed to the repo:

1. Copy the dashboard's YAML to a scratch file, then in that copy:
   - rename `metadata.name` (e.g. `proxmox-overview` → `proxmox-overview-dev`)
   - change the `grafana_folder` annotation to `"Dev"` so it doesn't
     land next to the real dashboards
   - change the embedded JSON's `uid` and `title` so it doesn't
     collide with the real dashboard (e.g. `adnvjd7` → `adnvjd7-dev`,
     `"Proxmox Overview"` → `"Proxmox Overview (dev)"`)
2. `kubectl -n observability apply -f <scratch-file>` - the sidecar
   picks it up within ~15s and it shows up in Grafana's "Dev" folder.
   Flux never sees it, so it sits there untouched for as long as you
   want, through as many edit/apply cycles as you need.
3. Once you're happy, fold the changes into the real committed file
   and open a PR as usual.
4. `kubectl -n observability delete configmap proxmox-overview-dev`
   (or whatever you named it) to clean up.

## Accessing Grafana

Get the admin password:
```bash
kubectl get secret -n observability kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```
