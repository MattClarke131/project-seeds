# Leantime

Goals-focused project management, for a volunteer-feedback trial alongside
Wekan (`wekan-trial` branch/PR) in the shared `project-management`
namespace.

## Dependencies

- Shared Postgres cluster (`infrastructure/kubernetes/database`) — this PR
  adds `project-management` to its
  `reflection-allowed-namespaces` annotation and provisions a `leantime`
  database via `leantime/database.yaml`.
- Pangolin tunnel — `leantime.labmatt.com` is added to `tunnel_hostnames`
  in `infrastructure/cloudflare/opentofu`. After this deploys, create the
  matching resource + access rule in the Pangolin dashboard.

## Deploy order

```bash
kubectl apply -f services/project-management/namespace.yaml
kubectl apply -f services/project-management/leantime/database.yaml
kubectl apply -f services/project-management/leantime/secret.yaml
kubectl create secret generic leantime-session -n project-management \
  --from-literal=LEAN_SESSION_PASSWORD=$(openssl rand -hex 32)
kubectl apply -f services/project-management/leantime/pvc.yaml
kubectl apply -f services/project-management/leantime/deployment.yaml
kubectl apply -f services/project-management/leantime/service.yaml
kubectl apply -f services/project-management/leantime/ingress.yaml
```

Also re-apply the edited `postgres-cluster.yaml` and run
`tofu apply` in `infrastructure/cloudflare/opentofu`.

First run creates an admin account at first login on
`leantime.labmatt.com`.
