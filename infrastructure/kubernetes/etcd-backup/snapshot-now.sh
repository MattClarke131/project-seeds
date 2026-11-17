#!/usr/bin/env bash
# Take an etcd snapshot now by running the etcd-snapshot CronJob as a one-off Job.
# Prints the Job's logs. Exits non-zero if the Job fails or times out.
set -euo pipefail

NAMESPACE=etcd-backup
JOB="pre-change-$(date +%Y%m%d-%H%M)"
TIMEOUT_SECONDS=300

kubectl create job -n "$NAMESPACE" --from=cronjob/etcd-snapshot "$JOB"

# Poll both conditions, since `kubectl wait --for=condition=complete` hangs until timeout on failure.
deadline=$((SECONDS + TIMEOUT_SECONDS))
result=""
while [ "$SECONDS" -lt "$deadline" ]; do
  conditions=$(kubectl get job -n "$NAMESPACE" "$JOB" \
    -o jsonpath='{.status.conditions[?(@.status=="True")].type}')
  case " $conditions " in
    *" Complete "*) result=Complete; break ;;
    *" Failed "*) result=Failed; break ;;
  esac
  sleep 5
done

echo "--- logs: job/$JOB"
kubectl logs -n "$NAMESPACE" "job/$JOB" --all-containers || true

case "$result" in
  Complete) echo "OK: job/$JOB completed" ;;
  Failed) echo "FAIL: job/$JOB failed" >&2; exit 1 ;;
  *) echo "FAIL: job/$JOB did not finish within ${TIMEOUT_SECONDS}s" >&2; exit 1 ;;
esac
