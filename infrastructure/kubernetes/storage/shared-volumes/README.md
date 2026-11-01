# Shared volumes

Kustomize components for NFS exports that more than one namespace mounts.

A PV binds to exactly one PVC, and PVCs are namespaced, so every consuming namespace needs its own PV. Each component defines the NFS details once. Each consumer stamps out its own copy.

These components are not listed in `../kustomization.yaml`. They only render through the consumers that include them.

## Adding a consumer

In the consumer's `kustomization.yaml`, include the component and give the PV a name unique to that consumer:

```yaml
components:
  - ../../infrastructure/kubernetes/storage/shared-volumes/media-standard
patches:
  - target:
      kind: PersistentVolume
      name: media-standard-RENAME-ME
    patch: |-
      - op: replace
        path: /metadata/name
        value: media-standard-<consumer>
```

Then point the consumer's PVC at it with `volumeName: media-standard-<consumer>` and `storageClassName: ""`.

The placeholder name contains uppercase letters, so a consumer that forgets the rename fails to apply. It can't silently collide with another consumer's PV.

PVs are cluster-scoped and owned by the consumer's Flux Kustomization. Removing a consumer prunes its PV. The `Retain` policy and static NFS backing leave the data on the export untouched.

## Current consumers

| Component | PV | Consumer |
|---|---|---|
| `media-standard` | `media-standard` | `services/jellyfin` |
| `media-standard` | `media-standard-downloads` | `services/downloads-standard` |
