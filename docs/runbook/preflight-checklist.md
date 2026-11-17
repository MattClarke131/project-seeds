# Preflight Checklist

Complete this before any change that could take down a node, a host, or stored data. Examples: draining or resizing a VM, rebooting a Proxmox host or TrueNAS, upgrading Talos or Kubernetes, or bumping a major version on a stateful HelmRelease.

[`scripts/preflight.sh`](../../scripts/preflight.sh) runs every gate in section 1 except the rollback plan, which stays manual. It prints one PASS, WARN, or FAIL line per gate. This document is the source of truth. If the two disagree, fix the script.

```bash
scripts/preflight.sh --host <host>   # repeat --host for each host the change touches, or pass --host all
```

## 1. Go/no-go gates

Every gate is read-only.

| Gate | Command | Expected result |
| --- | --- | --- |
| Nodes Ready | `kubectl get nodes` | Every node `Ready` |
| Flux Ready | `flux get kustomizations` | Every kustomization `READY True` and `SUSPENDED False` |
| CNPG healthy | `kubectl get cluster.postgresql.cnpg.io -A` | Every cluster `Cluster in healthy state`, with `READY` equal to `INSTANCES` |
| zpools healthy | `ssh <host> zpool status -x` for `razlo`, `nicholas`, `livio`, and `sleipnir` | `all pools are healthy` |
| Host memory | `ssh <host> free -m` for `razlo`, `nicholas`, and `livio` | At least 2048 in the `available` column |
| Recent etcd backup | `kubectl get jobs -n etcd-backup` | A job with `COMPLETIONS 1/1` that finished in the last 24h |
| Rollback plan | None, not checked by the script | Written down: how to undo the change, and how long that takes |

### Degraded pools

A degraded pool blocks only changes on its own host. On any other host, it is a warning.

- **Why:** a degraded single-disk `rpool` can stall its host's I/O. That risk matters when the change stresses that host. Blocking every change would also block unrelated work for as long as the disk waits on a physical fix.
- **In the script:** pass `--host` for each host the change touches. A degraded pool on a `--host` host fails the gate. Anywhere else, it prints `WARN`.
- **Cluster-wide changes:** a Talos or Kubernetes upgrade touches every host, so pass `--host all`.

## 2. Safety snapshots

Take these after the gates pass and immediately before the change. Use one short `<change>` name for both, such as `pre-talos-v1.15.0` or `pre-prometheus-v88.5.4`.

1. **etcd**:
   ```bash
   infrastructure/kubernetes/etcd-backup/snapshot-now.sh
   ```
   Expected: the logs show `etcd snapshot saved`, and the script ends with `OK: job/pre-change-<timestamp> completed`.
   - The snapshot file is named by date, so it replaces that day's 03:00 snapshot with a newer one.
2. **ZFS**, for any change that touches stored data. TrueNAS asks for the `truenas_admin` password.
   ```bash
   ssh -t sleipnir sudo zfs snapshot -r sleipnir/k8s@pre-<change>
   ssh -t sleipnir sudo zfs snapshot -r sleipnir/k8s-iscsi@pre-<change>
   ```
   Expected: no output. Then confirm with:
   ```bash
   ssh sleipnir zfs list -t snapshot -o name | grep '@pre-<change>$'
   ```
   Expected: one line per dataset and child dataset.
   - These snapshots are independent of the automatic schedule, which expires daily snapshots after 30 days. Destroy them once the change is confirmed good:
     ```bash
     ssh -t sleipnir sudo zfs destroy -r sleipnir/k8s@pre-<change>
     ssh -t sleipnir sudo zfs destroy -r sleipnir/k8s-iscsi@pre-<change>
     ```

## 3. Go or abort

Proceed only when every gate in section 1 passes and every snapshot in section 2 succeeded. `preflight.sh` ends with `GO` or `ABORT` to match.

If a gate fails, fix the cause first, or decide in writing why the change is safe anyway.
