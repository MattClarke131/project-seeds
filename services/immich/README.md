# immich

Self-hosted photo library. https://immich.app

## Dependencies

- CNPG operator installed in cluster
- NFS storage class `nfs-provisioner` available
- Secrets created (see below)
- `/mnt/sleipnir/photos` dataset and NFS share created on sleipnir

## Required secrets

### immich-db-superuser
```
kubectl create secret generic immich-db-superuser \
  --namespace immich \
  --from-literal=username=postgres \
  --from-literal=password=<strong-password>
```

### immich-db-user
```
kubectl create secret generic immich-db-user \
  --namespace immich \
  --from-literal=username=immich \
  --from-literal=password=<strong-password>
```

## Deployment order

1. Prepare the photos NFS share on sleipnir:
```
mkdir -p /mnt/sleipnir/photos/{thumbs,upload,backups,library,profile,encoded-video}
touch /mnt/sleipnir/photos/{thumbs,upload,backups,library,profile,encoded-video}/.immich
```
2. Create secrets (above) - Flux doesn't manage these, see the Secrets section
3. Everything else (namespace, CNPG cluster, library PVC, the `immich` Helm
   release via `HelmRepository`/`HelmRelease`) is Flux-managed - merging to
   `main` is the deploy step.

## Post-deploy notes

The CNPG `postInitSQL` should handle extension creation automatically on fresh installs.
If the immich-server crashes with extension permission errors, run manually as superuser:

```
kubectl exec -n immich -it immich-db-1 -- psql -U postgres -d immich -c "
CREATE EXTENSION IF NOT EXISTS vchord CASCADE;
CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;
CREATE EXTENSION IF NOT EXISTS cube CASCADE;
"
kubectl rollout restart deployment/immich-server -n immich
```
