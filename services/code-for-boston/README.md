# code-for-boston

Apps serving the Code for Boston volunteer group. Flux-managed — see
`clusters/eye-of-michael/flux-system/code-for-boston.yaml` for the
Kustomization CR that reconciles this path.

## Leantime

Goals-focused project management, deployed in the shared
`code-for-boston` namespace.

### Dependencies

- Needs MySQL, not the shared Postgres cluster used elsewhere in this
  repo: the `leantime/leantime` Docker image has no `pdo_pgsql` PHP
  extension (only `pdo_mysql`), so it gets its own single-instance
  MariaDB (`mariadb/`) reachable only in-cluster.
- Pangolin tunnel — `leantime.labmatt.com` is added to `tunnel_hostnames`
  in `infrastructure/cloudflare/opentofu`.

First run creates an admin account at first login on
`leantime.labmatt.com`.

## Manual steps (not yet automated)

These aren't covered by Flux and need doing once, after merge:

```bash
kubectl create secret generic leantime-session -n code-for-boston \
  --from-literal=LEAN_SESSION_PASSWORD=$(openssl rand -hex 32)

kubectl create secret generic leantime-mysql-credentials -n code-for-boston \
  --from-literal=username=leantime \
  --from-literal=password=$(openssl rand -hex 32) \
  --from-literal=root-password=$(openssl rand -hex 32)
```

Also run `tofu apply` in `infrastructure/cloudflare/opentofu` for the new
`leantime.labmatt.com` DNS record (tracked for automation in #57), and
create the matching resource + access rule in the Pangolin dashboard per
`infrastructure/tunnel/blueprints/README.md` (tracked in #7).

Blueprints don't cover deletion: removing a resource (e.g. Wekan's) from
`tunnel_hostnames` still needs its Pangolin resource and access rule
deleted by hand in the dashboard.
