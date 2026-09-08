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

Data Protection > Periodic Snapshot Tasks > Add
- Dataset: `sleipnir/k8s`
- Recursive: yes
- Naming schema: `auto-%Y-%m-%d_%H-%M`
- Schedule 1 (hourly): every hour, keep for 48 hours
- Schedule 2 (daily): once a day, keep for 30 days

Add both as separate Periodic Snapshot Tasks on the same dataset - TrueNAS
doesn't support mixed retention within a single task.

### Runbook: before a major stateful upgrade

Before bumping a major version on any stateful HelmRelease (Postgres,
Prometheus, or anything else with a PVC on `nfs-provisioner`), take a
manual snapshot first so there's a known-good rollback point independent
of the automatic schedule:

```
zfs snapshot -r sleipnir/k8s@pre-<component>-<version>
```

e.g. `zfs snapshot -r sleipnir/k8s@pre-prometheus-v88.5.4`
