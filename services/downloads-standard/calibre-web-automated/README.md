# calibre-web-automated

Ebook library + Kobo device sync. See GitHub issue #17 for the full design
(two-hostname split: `books.labmatt.com` tailnet-only admin UI,
`books-sync.labmatt.com` path-restricted Kobo sync via Pangolin).

The manifests here are Flux-managed (`services/downloads-standard/
kustomization.yaml`) - merging to `main` deploys them, no manual
`kubectl apply` needed. DNS (`infrastructure/cloudflare/opentofu`) and the
Pangolin Resource (`infrastructure/tunnel/blueprints/books-sync.yaml`) for
`books-sync.labmatt.com` are handled in their own directories - see those
for the apply steps. Once those are applied:

1. In CWA's admin UI (`books.labmatt.com`), enable Kobo Sync and generate
   the per-user sync token/URL.
2. On the Kobo device, point it at
   `https://books-sync.labmatt.com/kobo/<token>/`.
