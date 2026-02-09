#!/bin/bash

POOL_USED=$(zpool list -Hp -o allocated sleipnir)
POOL_TOTAL=$(zpool list -Hp -o size sleipnir)
echo "scale.truenas.zpool.used $POOL_USED $(date +%s)" | nc -w1 10.0.10.31 32003
echo "scale.truenas.zpool.total $POOL_TOTAL $(date +%s)" | nc -w1 10.0.10.31 32003
