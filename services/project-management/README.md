# Leantime

Goals-focused project management, for a volunteer-feedback trial alongside
Wekan (`wekan-trial` branch/PR) in the shared `project-management`
namespace. Flux-managed — see
`clusters/eye-of-michael/flux-system/project-management.yaml` for the
Kustomization CR that reconciles this path.

## Dependencies

- `databases/code-for-boston` cluster (#118) — must merge first. This PR
  still needs a follow-up commit once it does: add a dedicated
  `leantime` role there (least-privilege: just the `leantime` database,
  not the internal cluster's shared `app` role), a matching `pg_hba`
  line, and `project-management` to `reflection-allowed-namespaces`.
- Pangolin tunnel — `leantime.labmatt.com` is added to `tunnel_hostnames`
  in `infrastructure/cloudflare/opentofu`.

## Manual steps (not yet automated)

These aren't covered by Flux and need doing once, after merge:

```bash
kubectl create secret generic leantime-session -n project-management \
  --from-literal=LEAN_SESSION_PASSWORD=$(openssl rand -hex 32)

kubectl create secret generic leantime-postgres-credentials \
  -n code-for-boston \
  --from-literal=username=leantime \
  --from-literal=password=$(openssl rand -hex 32)
```

Also run `tofu apply` in `infrastructure/cloudflare/opentofu` for the DNS
record (tracked for automation in #57), and create the matching resource
+ access rule in the Pangolin dashboard (tracked in #7).

First run creates an admin account at first login on
`leantime.labmatt.com`.
