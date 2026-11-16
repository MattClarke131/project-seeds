# TrueNAS

## Configuring TrueNAS reporting
Reporting > Exporters > Add
- Type: GRAPHIE
- Destination IP:
- Destination Port:
- Namespace: truenas

## Custom reporting scripts
1. Copy scripts from the `scripts` directory to the TrueNAS server at `/mnt/<pool>/scripts/`
2. Make the scripts executable:
```bash
chmod +x /mnt/<pool>/scripts/*.sh
```
3. Set up a cron job in the TrueNAS UI.
- Advanced Settings > Cron Jobs > Add
- Command: `/mnt/<pool>/scripts/send_zpool_metrics.sh`
- Schedule: Every Minute (or as desired)
- User: root

## ZFS snapshot policy (sleipnir/k8s)

Protects against write mistakes (bad rollout, corrupted upgrade, wrong
`rm`) on the `nfs-provisioner` storage class - not against drive failure
(RAIDZ2 already covers that) and not a substitute for off-site backup
(see #111). Snapshots are copy-on-write, so cost is proportional to churn
between snapshots, not dataset size - negligible at this pool's scale.

**What's covered:** everything provisioned by the `nfs-provisioner`
storage class lives under `sleipnir/k8s`, so recursive snapshots on that
dataset catch it all - Postgres, Prometheus, Loki, Grafana, Immich's DB,
Jellyfin's config/library-index PVC, and every other app's config PVC on
that class.

**What's NOT covered:** any volume outside `sleipnir/k8s`, most notably
the bulk media library. `jellyfin-media` and the `*arr` apps' media PVCs
bind to the statically-provisioned `media-standard` PV
(`services/downloads-standard/pv-media-standard.yaml`), which points at
NFS export `/mnt/sleipnir/media-standard` - a separate dataset entirely.
Media files get no snapshot coverage from this policy.

Data Protection > Periodic Snapshot Tasks > Add
- Dataset: `sleipnir/k8s`
- Recursive: yes
- Naming schema: `auto-%Y-%m-%d_%H-%M`
- Schedule 1 (hourly): every hour, keep for 48 hours
- Schedule 2 (daily): once a day, keep for 30 days

Add both as separate Periodic Snapshot Tasks on the same dataset - TrueNAS
doesn't support mixed retention within a single task.

## ZFS snapshot policy (sleipnir/k8s-iscsi)

`sleipnir/k8s-iscsi` is a sibling dataset to `sleipnir/k8s`, not a child
of it - the `truenas-iscsi` storage class (democratic-csi, #13) provisions
here instead of `nfs-provisioner`, so nothing above reaches it. It holds
the `downloads-standard` config PVCs #13 migrated off `nfs-provisioner`
for RWOP safety, plus `cwa-library-iscsi` - Calibre-Web-Automated's actual
book library, not just its config. Same write-mistake exposure as #100
started with, on a separate dataset, so it gets the same policy:

Data Protection > Periodic Snapshot Tasks > Add
- Dataset: `sleipnir/k8s-iscsi`
- Recursive: yes
- Naming schema: `auto-%Y-%m-%d_%H-%M`
- Schedule 1 (hourly): every hour, keep for 48 hours
- Schedule 2 (daily): once a day, keep for 30 days

Same two-task-per-dataset split as above.

### Runbook: before a major stateful upgrade

Before bumping a major version on any stateful HelmRelease (Postgres,
Prometheus, or anything else with a PVC on `nfs-provisioner` or
`truenas-iscsi`), take a manual snapshot first so there's a known-good
rollback point independent of the automatic schedule:

```
zfs snapshot -r sleipnir/k8s@pre-<component>-<version>
zfs snapshot -r sleipnir/k8s-iscsi@pre-<component>-<version>
```

e.g. `zfs snapshot -r sleipnir/k8s@pre-prometheus-v88.5.4`
