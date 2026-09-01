# democratic-csi (TrueNAS iSCSI)

Adds a second StorageClass, `truenas-iscsi`, backed by iSCSI zvols on the
`sleipnir` TrueNAS pool. Provisioned via [democratic-csi](https://github.com/democratic-csi/democratic-csi)'s
`freenas-api-iscsi` driver, talking to the TrueNAS SCALE REST API.

Exists to close #13: `nfs-provisioner` doesn't enforce `ReadWriteOnce`
exclusivity, which already corrupted Bazarr's SQLite config db. iSCSI zvols
are real block devices - single-initiator by nature - so the driver can
enforce `ReadWriteOncePod` and Kubernetes will reject a double-attach
outright, instead of relying on every deployment remembering
`strategy: Recreate`.

`nfs-provisioner` stays as-is and stays default - bulk media storage and
anything that wants RWX has no reason to move. Only the 9 single-replica
config PVCs listed in #13 (plus any others found) are in scope for
migration, and that migration is **not** part of this change - see
"Migrating a PVC" below for why it's deliberately left as a separate step.

## Prerequisite: Talos needs the `iscsi-tools` system extension

Talos ships without `iscsiadm` on the host. Without it, the democratic-csi
node driver's `NodeStageVolume` calls fail outright - the pod using the
volume gets stuck in `ContainerCreating`. Before this HelmRelease will work
on *any* node, every node needs the
[`iscsi-tools`](https://github.com/siderolabs/extensions/tree/main/storage/iscsi-tools)
extension added to its Talos machine config and a reboot applied. This is a
per-node Talos image change, not something this HelmRelease or Kubernetes
manifests can do - it has to happen first, out of band, on all 9 nodes.

## Prerequisite: TrueNAS-side setup

None of this exists yet on `sleipnir` - do these in the TrueNAS SCALE UI
before the Secret below can be filled in with real values:

1. **Enable the iSCSI service.** Services -> iSCSI -> enable, start
   automatically.
2. **Create a portal.** Sharing -> Block Shares (iSCSI) -> Portals -> Add.
   Bind it to the TrueNAS IP the cluster already reaches it on (`10.0.10.20`,
   per `docs/bootstrap/kubernetes-storage.md` - remember pod traffic NATs
   through the Proxmox `192.168.1.0/24` subnet at the TrueNAS side, same as
   the existing NFS share). Note the **Portal Group ID** it's assigned.
3. **Create an initiator group.** Same section -> Initiators -> Add. Since
   the cluster's iSCSI initiator IPs will NAT through the same Proxmox
   subnet as NFS does today, this will likely need to allow that subnet
   rather than per-node IPs - confirm against how the existing NFS share's
   permissions are scoped. Note the **Initiator Group ID**.
4. **Create the parent dataset(s).** e.g. `sleipnir/k8s-iscsi/v` for volumes
   and `sleipnir/k8s-iscsi/s` for detached snapshots - siblings, not nested,
   per democratic-csi's requirement that they not overlap.
5. **Create an API key.** Settings (top right) -> API Keys -> Add. This is
   what fills in `apiKey` below - scope it to what democratic-csi needs if
   TrueNAS SCALE's key scoping allows narrowing it.

## Creating the Secret

`secret.example.yaml` shows the shape. This repo's Flux setup keeps
API-key-bearing Secrets out of `kustomization.yaml` (see
`infrastructure/kubernetes/cert-manager/README.md` for the same pattern
with `cloudflare-api-token`) so they're created imperatively and Flux never
prunes them:

```bash
kubectl create namespace democratic-csi

# fill in secret.example.yaml's placeholders with real values from the
# TrueNAS steps above, then:
kubectl create secret generic democratic-csi-truenas \
  --namespace democratic-csi \
  --from-file=values.yaml=./secret.filled-in.yaml
```

The HelmRelease won't reconcile successfully until this Secret exists.

## Migrating a PVC

Deliberately out of scope for this change - each of the 9 PVCs in #13 holds
live app state (several already migrated to Postgres, but config/state
still lives on these), and getting the copy-cutover sequence wrong risks
the exact corruption this is meant to fix. Once the above is validated (a
throwaway PVC on `truenas-iscsi` actually gets rejected on double-mount),
migrate one app at a time as a separate, reviewed change:

1. Scale the deployment to 0.
2. Create a new PVC on `truenas-iscsi`.
3. Copy data across (e.g. a one-off `Job` mounting both PVCs, `rsync` or
   `cp -a` between them).
4. Repoint the deployment's `volumes` at the new PVC, drop
   `strategy: Recreate` in favor of the default `RollingUpdate`.
5. Scale back up, verify, then delete the old PVC (and its `nfs-provisioner`
   backing directory) only after confirming the app is healthy on the new
   volume.
