#!/usr/bin/env bash
# Run the go/no-go gates from docs/runbook/preflight-checklist.md.
# Prints one PASS/WARN/FAIL line per gate. Exits non-zero if any gate fails.
#
# Usage: scripts/preflight.sh [--host <name>]...
#   --host  Proxmox host or TrueNAS the change touches (razlo, nicholas,
#           livio, sleipnir, or all). A degraded pool fails the gate on
#           these hosts and only warns on the others.
set -uo pipefail

PROXMOX_HOSTS=(razlo nicholas livio)
TRUENAS_HOST=sleipnir
MIN_AVAILABLE_MB=2048
MAX_BACKUP_AGE_HOURS=24
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10)

targets=()
while [ $# -gt 0 ]; do
  case "$1" in
    --host)
      [ $# -ge 2 ] || { echo "--host needs a value" >&2; exit 2; }
      case "$2" in
        razlo|nicholas|livio|sleipnir|all) targets+=("$2") ;;
        *) echo "unknown host: $2" >&2; exit 2 ;;
      esac
      shift 2
      ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

failures=0
warnings=0

report() {
  local status=$1 gate=$2 detail=$3
  printf '%-5s %-28s %s\n' "$status" "$gate" "$detail"
  case "$status" in
    FAIL) failures=$((failures + 1)) ;;
    WARN) warnings=$((warnings + 1)) ;;
  esac
}

is_target() {
  local host=$1 t
  for t in "${targets[@]+"${targets[@]}"}"; do
    [ "$t" = all ] || [ "$t" = "$host" ] && return 0
  done
  return 1
}

check_nodes() {
  local out
  if ! out=$(kubectl get nodes -o json 2>&1); then
    report FAIL nodes-ready "kubectl failed: $out"
    return
  fi
  local not_ready total
  total=$(jq '.items | length' <<<"$out")
  not_ready=$(jq -r '[.items[]
    | select(any(.status.conditions[]; .type == "Ready" and .status == "True") | not)
    | .metadata.name] | join(",")' <<<"$out")
  if [ -z "$not_ready" ]; then
    report PASS nodes-ready "$total/$total Ready"
  else
    report FAIL nodes-ready "not Ready: $not_ready"
  fi
}

check_flux() {
  local out
  if ! out=$(kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A -o json 2>&1); then
    report FAIL flux-ready "kubectl failed: $out"
    return
  fi
  local bad total
  total=$(jq '.items | length' <<<"$out")
  bad=$(jq -r '[.items[]
    | select(.spec.suspend == true
        or (any(.status.conditions[]?; .type == "Ready" and .status == "True") | not))
    | .metadata.name] | join(",")' <<<"$out")
  if [ -z "$bad" ]; then
    report PASS flux-ready "$total/$total kustomizations Ready"
  else
    report FAIL flux-ready "not Ready or suspended: $bad"
  fi
}

check_cnpg() {
  local out
  if ! out=$(kubectl get clusters.postgresql.cnpg.io -A -o json 2>&1); then
    report FAIL cnpg-healthy "kubectl failed: $out"
    return
  fi
  local bad total
  total=$(jq '.items | length' <<<"$out")
  bad=$(jq -r '[.items[]
    | select(.status.phase != "Cluster in healthy state"
        or .status.readyInstances != .spec.instances)
    | "\(.metadata.namespace)/\(.metadata.name)"] | join(",")' <<<"$out")
  if [ -z "$bad" ]; then
    report PASS cnpg-healthy "$total/$total clusters healthy"
  else
    report FAIL cnpg-healthy "unhealthy: $bad"
  fi
}

check_zpool() {
  local host=$1 out
  if ! out=$(ssh "${SSH_OPTS[@]}" "$host" zpool status -x 2>&1); then
    report FAIL "zpool-$host" "ssh or zpool failed: $(head -1 <<<"$out")"
    return
  fi
  if [ "$out" = "all pools are healthy" ]; then
    report PASS "zpool-$host" "all pools healthy"
    return
  fi
  local pools
  pools=$(awk '$1 == "pool:" {printf "%s%s", sep, $2; sep=","}' <<<"$out")
  if is_target "$host"; then
    report FAIL "zpool-$host" "unhealthy: $pools (change targets this host)"
  else
    report WARN "zpool-$host" "unhealthy: $pools (change does not target this host)"
  fi
}

check_memory() {
  local host=$1 available
  if ! available=$(ssh "${SSH_OPTS[@]}" "$host" "free -m | awk '/^Mem:/ {print \$7}'" 2>&1) \
      || ! [[ "$available" =~ ^[0-9]+$ ]]; then
    report FAIL "memory-$host" "ssh or free failed: $(head -1 <<<"$available")"
    return
  fi
  if [ "$available" -ge "$MIN_AVAILABLE_MB" ]; then
    report PASS "memory-$host" "${available} MB available (min ${MIN_AVAILABLE_MB})"
  else
    report FAIL "memory-$host" "${available} MB available (min ${MIN_AVAILABLE_MB})"
  fi
}

check_etcd_backup() {
  local out
  if ! out=$(kubectl get jobs -n etcd-backup -o json 2>&1); then
    report FAIL etcd-backup-recent "kubectl failed: $out"
    return
  fi
  # Newest successful job's age in hours, or empty if none succeeded.
  local age
  age=$(jq -r '[.items[]
    | select((.status.succeeded // 0) >= 1 and .status.completionTime != null)
    | .status.completionTime | fromdateiso8601]
    | max // empty | (now - .) / 3600 | floor' <<<"$out")
  if [ -z "$age" ]; then
    report FAIL etcd-backup-recent "no successful etcd-backup job found"
  elif [ "$age" -lt "$MAX_BACKUP_AGE_HOURS" ]; then
    report PASS etcd-backup-recent "last success ${age}h ago (max ${MAX_BACKUP_AGE_HOURS}h)"
  else
    report FAIL etcd-backup-recent "last success ${age}h ago (max ${MAX_BACKUP_AGE_HOURS}h)"
  fi
}

check_nodes
check_flux
check_cnpg
for host in "${PROXMOX_HOSTS[@]}" "$TRUENAS_HOST"; do
  check_zpool "$host"
done
for host in "${PROXMOX_HOSTS[@]}"; do
  check_memory "$host"
done
check_etcd_backup

echo
if [ "$failures" -gt 0 ]; then
  echo "ABORT: $failures gate(s) failed, $warnings warning(s)"
  exit 1
fi
echo "GO: all gates passed, $warnings warning(s)"
