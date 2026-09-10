#!/bin/bash

POOL_USED=$(zpool list -Hp -o allocated sleipnir)
POOL_TOTAL=$(zpool list -Hp -o size sleipnir)
DATASET_USED=$(zfs list -Hp -o used sleipnir/k8s)
SNAPSHOT_USED=$(zfs list -t snapshot -Hp -o used -r sleipnir/k8s | awk '{sum+=$1} END{print sum+0}')
echo "scale.truenas.zpool.used $POOL_USED $(date +%s)" | nc -w1 10.0.10.31 32003
echo "scale.truenas.zpool.total $POOL_TOTAL $(date +%s)" | nc -w1 10.0.10.31 32003
echo "scale.truenas.dataset.k8s.used $DATASET_USED $(date +%s)" | nc -w1 10.0.10.31 32003
echo "scale.truenas.dataset.k8s.snapshot_used $SNAPSHOT_USED $(date +%s)" | nc -w1 10.0.10.31 32003
