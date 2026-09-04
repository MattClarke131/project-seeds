# democratic-csi (TrueNAS iSCSI)

Adds a second StorageClass, `truenas-iscsi`, backed by iSCSI zvols on the
`sleipnir` TrueNAS pool. Provisioned via [democratic-csi](https://github.com/democratic-csi/democratic-csi)'s
`freenas-api-iscsi` driver, talking to the TrueNAS SCALE REST API. See #13
for why. `nfs-provisioner` stays default; nothing about it changes here.

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

Same pattern as cert-manager's `cloudflare-api-token`
(`infrastructure/kubernetes/cert-manager/README.md`): created imperatively,
never committed, kept out of `kustomization.yaml` so Flux never prunes it.

Only the API key is secret - everything else about the driver (TrueNAS
host, dataset names, portal/initiator group IDs, iSCSI settings) lives in
`helmrelease.yaml`, committed and reviewable like normal:

```bash
kubectl create namespace democratic-csi

kubectl create secret generic democratic-csi-truenas \
  --namespace democratic-csi \
  --from-file=values.yaml=/dev/stdin <<'EOF'
driver:
  config:
    httpConnection:
      apiKey: "<TRUENAS_API_KEY>"
EOF
```

The HelmRelease won't reconcile successfully until this Secret exists, and
`helmrelease.yaml`'s `targetGroupPortalGroup`/`targetGroupInitiatorGroup`
placeholders are filled in with real IDs from the TrueNAS setup above.
