#!/bin/bash
# node-exporter textfile collector for ZFS pool health (issue #142).
# Install per docs/bootstrap/host-monitoring.md. Writes atomically (temp file
# + mv) so node-exporter never reads a half-written file mid-scrape.
set -euo pipefail

TEXTFILE_DIR="/var/lib/prometheus/node-exporter"
OUT="$TEXTFILE_DIR/zpool_health.prom.$$"
FINAL="$TEXTFILE_DIR/zpool_health.prom"

{
  echo "# HELP zpool_health_ok Whether a ZFS pool is in ONLINE state (1) or not (0)."
  echo "# TYPE zpool_health_ok gauge"
  echo "# HELP zpool_errors_total Read/write/checksum errors reported by zpool status, summed across all vdev lines for the pool."
  echo "# TYPE zpool_errors_total gauge"

  zpool list -Ho name | while read -r pool; do
    health=$(zpool list -Ho health "$pool")
    ok=0
    [ "$health" = "ONLINE" ] && ok=1
    echo "zpool_health_ok{pool=\"$pool\"} $ok"

    # Vdev lines in `zpool status` output are the only ones with exactly
    # NAME STATE READ WRITE CKSUM (5 fields, last 3 numeric) - this also
    # matches the header row's NAME/STATE columns being non-numeric, so it's
    # naturally excluded.
    zpool status "$pool" | awk -v pool="$pool" '
      NF == 5 && $3 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ && $5 ~ /^[0-9]+$/ {
        read += $3; write += $4; cksum += $5
      }
      END {
        printf "zpool_errors_total{pool=\"%s\", type=\"read\"} %d\n", pool, read+0
        printf "zpool_errors_total{pool=\"%s\", type=\"write\"} %d\n", pool, write+0
        printf "zpool_errors_total{pool=\"%s\", type=\"cksum\"} %d\n", pool, cksum+0
      }'
  done

  echo "# HELP zpool_health_textfile_timestamp_seconds Unix time this file was last generated."
  echo "# TYPE zpool_health_textfile_timestamp_seconds gauge"
  echo "zpool_health_textfile_timestamp_seconds $(date +%s)"
} > "$OUT"

mv "$OUT" "$FINAL"
