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

## ZFS pool health (issue #142)

The Debian `prometheus-node-exporter` package already enables the textfile
collector by default, reading `/var/lib/prometheus/node-exporter`. Confirm
this on each host before proceeding:
```bash
grep textfile /etc/default/prometheus-node-exporter
```
If that directory isn't set, add
`ARGS="--collector.textfile.directory=/var/lib/prometheus/node-exporter"` to
that file and `systemctl restart prometheus-node-exporter`.

Install the zpool health script and its systemd timer on each Proxmox host
(nicholas, livio, razlo). This is the one manual, SSH-driven step - once
installed, pool health flows into Prometheus/ntfy on its own with no further
SSH needed:
```bash
mkdir -p /var/lib/prometheus/node-exporter
cp zpool_health_textfile.sh /usr/local/bin/
chmod +x /usr/local/bin/zpool_health_textfile.sh
cp zpool-health.service zpool-health.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now zpool-health.timer
```
(scripts live in `infrastructure/proxmox/scripts/` in this repo)

### Verification
```bash
systemctl status zpool-health.timer
cat /var/lib/prometheus/node-exporter/zpool_health.prom
curl -s localhost:9100/metrics | grep zpool_
```

## SATA link resets (issue #143)

Counts `ataN: hard resetting link` kernel messages per port and reports each
port's link power management policy. The `SataLinkReset` alert fires on any
new reset. Install on each Proxmox host:
```bash
cp sata_link_textfile.sh /usr/local/bin/
chmod +x /usr/local/bin/sata_link_textfile.sh
cp sata-link.service sata-link.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now sata-link.timer
```

### Disabling SATA link power management (nicholas only)

nicholas's boot SSD (Phison PS3111-S11 controller) drops its link when waking
from the power-saving state, the same fault the kernel works around for the
PNY CS900. The kernel quirk matches by model name, and this drive reports a
generic `SATA SSD`, so the setting is applied by hand:
```bash
cp 90-sata-lpm.rules /etc/udev/rules.d/
udevadm control --reload
for f in /sys/class/scsi_host/host*/link_power_management_policy; do echo max_performance > "$f"; done
```
To undo, delete `/etc/udev/rules.d/90-sata-lpm.rules` and reboot.

### Verification
```bash
systemctl status sata-link.timer
cat /var/lib/prometheus/node-exporter/sata_link.prom
cat /sys/class/scsi_host/host*/link_power_management_policy
```
