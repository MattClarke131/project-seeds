# Vikunja

Task and project manager, reachable on the tailnet at https://vikunja.labmatt.com.
It also serves CalDAV for Tasks.org on Android and Wear OS.

- **Exposure:** tailnet only. `*.labmatt.com` resolves to the internal ingress, and there is no Pangolin blueprint.
- **State:** tasks and projects live in the shared CNPG `postgres` cluster (database and role `vikunja`). Attachments, avatars and backgrounds live on the `vikunja-files` PVC.

## Secrets

Both Secrets are live-only and must exist before merging. Use hex values so no character needs escaping in a connection string.

1. Postgres role password, reflected into the `vikunja` namespace:

   ```sh
   kubectl create secret generic postgres-vikunja \
     --namespace database \
     --type kubernetes.io/basic-auth \
     --from-literal=username=vikunja \
     --from-literal=password="$(openssl rand -hex 32)"
   kubectl annotate secret postgres-vikunja -n database \
     reflector.v1.k8s.emberstack.com/reflection-allowed=true \
     reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces=vikunja
   ```

2. JWT signing secret. Rotating it logs every session out.

   ```sh
   kubectl create namespace vikunja --dry-run=client -o yaml | kubectl apply -f -
   kubectl create secret generic vikunja-secret \
     --namespace vikunja \
     --from-literal=service-secret="$(openssl rand -hex 32)"
   ```

`pg_hba` in `infrastructure/kubernetes/database/postgres-cluster.yaml` allows the `vikunja` role only into its own database.

## First user

Registration is disabled. Create accounts with the CLI. It prompts for the password:

```sh
kubectl exec -it -n vikunja deploy/vikunja -- /app/vikunja/vikunja user create -u <username> -e <email>
```

## Tasks.org (CalDAV)

In Tasks.org, add a CalDAV account:

- **URL:** `https://vikunja.labmatt.com/dav/principals/<username>/`
- **Password:** a CalDAV token from Vikunja's Settings > CalDAV. Your login password works too, but a token can be revoked on its own.

## Verifying

```sh
kubectl logs -n vikunja -l app=vikunja -f
curl -s https://vikunja.labmatt.com/api/v1/info
```
