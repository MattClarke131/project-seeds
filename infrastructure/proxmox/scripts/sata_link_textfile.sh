#!/bin/bash
# node-exporter textfile collector for SATA link resets per ATA port (issue #143).
# Install per docs/bootstrap/host-monitoring.md. Writes atomically (temp file
# + mv) so node-exporter never reads a half-written file mid-scrape.
set -euo pipefail

TEXTFILE_DIR="/var/lib/prometheus/node-exporter"
OUT="$TEXTFILE_DIR/sata_link.prom.$$"
FINAL="$TEXTFILE_DIR/sata_link.prom"

# Counts since boot; Prometheus increase() handles the reset on reboot.
resets=$(journalctl -k -b --no-pager -o cat | grep -oE '^ata[0-9]+: hard resetting link' | cut -d: -f1 | sort | uniq -c || true)

{
  echo "# HELP sata_link_resets_total SATA link hard resets per ATA port since boot, from the kernel log."
  echo "# TYPE sata_link_resets_total counter"
  # Emit every port, including zeros, so the first reset shows as an increase.
  for port_path in /sys/class/ata_port/ata*; do
    port=$(basename "$port_path")
    count=$(awk -v p="$port" '$2 == p {print $1}' <<<"$resets")
    echo "sata_link_resets_total{port=\"$port\"} ${count:-0}"
  done

  echo "# HELP sata_link_lpm_policy_info SATA host link power management policy, value always 1."
  echo "# TYPE sata_link_lpm_policy_info gauge"
  for host_path in /sys/class/scsi_host/host*; do
    [ -r "$host_path/link_power_management_policy" ] || continue
    echo "sata_link_lpm_policy_info{scsi_host=\"$(basename "$host_path")\", policy=\"$(cat "$host_path/link_power_management_policy")\"} 1"
  done

  echo "# HELP sata_link_textfile_timestamp_seconds Unix time this file was last generated."
  echo "# TYPE sata_link_textfile_timestamp_seconds gauge"
  echo "sata_link_textfile_timestamp_seconds $(date +%s)"
} > "$OUT"

mv "$OUT" "$FINAL"
