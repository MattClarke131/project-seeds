# etcd Backup

Daily `talosctl etcd snapshot` of the cluster's etcd, kept 14 days on
TrueNAS-backed NFS storage. Etcd is already a 3-node HA quorum (livio-cp,
nicholas-cp, razlo-cp) so a single disk failure doesn't lose cluster state on
its own - this covers the remaining cases: a bad operation, correlated
failure, or losing quorum outright.

## Setup

The `etcd-backup-talosconfig` secret is committed empty and must be populated
manually after this namespace exists:

```bash
kubectl create secret generic etcd-backup-talosconfig -n etcd-backup \
  --from-file=talosconfig=<path-to-talosconfig> \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Restore

```bash
talosctl bootstrap --recover-from=<snapshot>
```

## Retention

14 daily snapshots - enough to survive a week-long absence plus slack to
notice a silently failed job on return. Cleanup runs as part of the same
CronJob (`find ... -mtime +14 -delete`), not a separate schedule.
