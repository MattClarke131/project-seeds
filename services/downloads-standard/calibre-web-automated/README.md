# calibre-web-automated

Ebook library + Kobo device sync. See GitHub issue #17 for the full design
(two-hostname split: `books.labmatt.com` tailnet-only admin UI,
`books-sync.labmatt.com` path-restricted Kobo sync via Pangolin).

The manifests here are Flux-managed (`services/downloads-standard/
kustomization.yaml`) - merging to `main` deploys them, no manual
`kubectl apply` needed. Two steps stay manual:

1. `tofu apply` in `infrastructure/cloudflare/opentofu` to create the
   `books-sync` DNS record (already added to `tunnel_hostnames`):
```bash
cd infrastructure/cloudflare/opentofu && tofu apply
```
2. Apply `infrastructure/tunnel/blueprints/books-sync.yaml` via the
   Pangolin dashboard's Settings > Blueprints page - see that
   directory's README for the full workflow. It points
   `books-sync.labmatt.com` at the `ingress-nginx` LoadBalancer (port
   80), same as `mattflix.labmatt.com` - **not** directly at the
   `calibre-web-automated` Service, which would bypass
   `ingress-books-sync.yaml`'s `/kobo/`-only path restriction and expose
   the full admin UI on this host. SSO is deliberately off for this
   resource (a Kobo can't complete an SSO redirect); optionally add a
   rate-limit rule on `/kobo/` by hand in the dashboard afterward - not
   expressible in the Blueprint schema, see the blueprint file's own
   comment.
3. In CWA's admin UI (`books.labmatt.com`), enable Kobo Sync and generate
   the per-user sync token/URL.
4. On the Kobo device, point it at
   `https://books-sync.labmatt.com/kobo/<token>/`.
