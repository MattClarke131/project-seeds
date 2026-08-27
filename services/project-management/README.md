# Leantime

Goals-focused project management, for a volunteer-feedback trial alongside
Wekan (`wekan-trial` branch/PR) in the shared `project-management`
namespace. Flux-managed — see
`clusters/eye-of-michael/flux-system/project-management.yaml` for the
Kustomization CR that reconciles this path.

## Dependencies

- Shared Postgres cluster (`infrastructure/kubernetes/database`) — this PR
  adds `project-management` to its `reflection-allowed-namespaces`
  annotation and provisions a `leantime` database via
  `leantime/database.yaml`.
- Pangolin tunnel — `leantime.labmatt.com` is added to `tunnel_hostnames`
  in `infrastructure/cloudflare/opentofu`.

## Manual steps (not yet automated)

These aren't covered by Flux and need doing once, after merge:

```bash
kubectl create secret generic leantime-session -n project-management \
  --from-literal=LEAN_SESSION_PASSWORD=$(openssl rand -hex 32)
```

Also run `tofu apply` in `infrastructure/cloudflare/opentofu` for the DNS
record (tracked for automation in #57), and create the matching resource
+ access rule in the Pangolin dashboard (tracked in #7).

First run creates an admin account at first login on
`leantime.labmatt.com`.
