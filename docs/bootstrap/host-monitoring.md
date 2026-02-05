# Host Monitoring Setup

Installing node-exporter on physical Proxmox hosts for hardware metrics collection.

## Overview
Node-exporter exposes hardware and OS metrics (CPU, memory, disk, network) from physical hosts. These metrics are scraped by Prometheus running in the Kubernetes cluster for infrastructure monitoring.

## Steps
Run on each Proxmox host (nicholas, livio, razlo):
```bash
apt install -y prometheus-node-exporter
```

The package automatically:
- Installs node-exporter binary
- Creates systemd service
- Starts exporter on port 9100

## Verification
```bash
systemctl status prometheus-node-exporter
curl localhost:9100/metrics | head -20
```
