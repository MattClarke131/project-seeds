# code-for-boston

Apps serving the Code for Boston volunteer group, plus the dedicated
Postgres cluster (`postgres/`) they share. Flux-managed — see
`clusters/eye-of-michael/flux-system/code-for-boston.yaml` for the
Kustomization CR that reconciles this path.

## Leantime

Goals-focused project management, for a volunteer-feedback trial
alongside Wekan (`wekan-trial` branch/PR) in the shared `code-for-boston`
namespace.

### Dependencies

- The `postgres/` cluster in this directory — a dedicated `leantime`
  role/database there (least-privilege: just the `leantime` database,
  not the internal cluster's shared `app` role), plus a matching
  `pg_hba` line and `code-for-boston` in
  `reflection-allowed-namespaces`.
- Pangolin tunnel — `leantime.labmatt.com` is added to `tunnel_hostnames`
  in `infrastructure/cloudflare/opentofu`.

### Manual steps (not yet automated)

These aren't covered by Flux and need doing once, after merge:

```bash
kubectl create secret generic leantime-session -n code-for-boston \
  --from-literal=LEAN_SESSION_PASSWORD=$(openssl rand -hex 32)

kubectl create secret generic leantime-postgres-credentials \
  -n code-for-boston-database \
  --from-literal=username=leantime \
  --from-literal=password=$(openssl rand -hex 32)
```

Also run `tofu apply` in `infrastructure/cloudflare/opentofu` for the DNS
record (tracked for automation in #57), and create the matching resource
+ access rule in the Pangolin dashboard per
`infrastructure/tunnel/blueprints/README.md` (tracked in #7).

First run creates an admin account at first login on
`leantime.labmatt.com`.
