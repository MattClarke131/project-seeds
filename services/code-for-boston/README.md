# code-for-boston

Apps serving the Code for Boston volunteer group. Flux-managed — see
`clusters/eye-of-michael/flux-system/code-for-boston.yaml` for the
Kustomization CR that reconciles this path.

No apps deployed here currently — Wekan and Leantime, both
volunteer-feedback trials, have been sunset. Only the namespace remains.

## Manual follow-up per app removal (not automated)

Blueprints don't cover deletion: removing a resource from
`tunnel_hostnames` still needs its Pangolin resource and access rule
deleted by hand in the dashboard, and its DNS record dropped via
`tofu apply` in `infrastructure/cloudflare/opentofu`.
