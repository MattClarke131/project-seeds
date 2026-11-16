#!/bin/bash
# Pushes ZFS pool/dataset usage that netdata's exporter doesn't send, via graphite plaintext.
# Target is graphite-exporter's LoadBalancer IP (observability ns), on the Service port.

POOL_USED=$(zpool list -Hp -o allocated sleipnir)
POOL_TOTAL=$(zpool list -Hp -o size sleipnir)
DATASET_USED=$(zfs list -Hp -o used sleipnir/k8s)
SNAPSHOT_USED=$(zfs list -t snapshot -Hp -o used -r sleipnir/k8s | awk '{sum+=$1} END{print sum+0}')
ISCSI_DATASET_USED=$(zfs list -Hp -o used sleipnir/k8s-iscsi)
ISCSI_SNAPSHOT_USED=$(zfs list -t snapshot -Hp -o used -r sleipnir/k8s-iscsi | awk '{sum+=$1} END{print sum+0}')
echo "scale.truenas.zpool.used $POOL_USED $(date +%s)" | nc -w1 10.0.10.61 2003
echo "scale.truenas.zpool.total $POOL_TOTAL $(date +%s)" | nc -w1 10.0.10.61 2003
echo "scale.truenas.dataset.k8s.used $DATASET_USED $(date +%s)" | nc -w1 10.0.10.61 2003
echo "scale.truenas.dataset.k8s.snapshot_used $SNAPSHOT_USED $(date +%s)" | nc -w1 10.0.10.61 2003
echo "scale.truenas.dataset.k8s_iscsi.used $ISCSI_DATASET_USED $(date +%s)" | nc -w1 10.0.10.61 2003
echo "scale.truenas.dataset.k8s_iscsi.snapshot_used $ISCSI_SNAPSHOT_USED $(date +%s)" | nc -w1 10.0.10.61 2003
