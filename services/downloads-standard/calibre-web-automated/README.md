# calibre-web-automated

Ebook library + Kobo device sync. See GitHub issue #17 for the full design
(two-hostname split: `books.labmatt.com` tailnet-only admin UI,
`books-sync.labmatt.com` path-restricted Kobo sync via Pangolin).

The manifests here handle the Kubernetes/DNS side; the following steps are
manual (Pangolin has no config-as-code yet, see
`infrastructure/tunnel/README.md`):

1. Apply the manifests and `tofu apply` in `infrastructure/cloudflare/opentofu`
   to create the `books-sync` DNS record:
```bash
kubectl apply -f .
cd ../../../infrastructure/cloudflare/opentofu && tofu apply
```
2. In the Pangolin dashboard, add `books-sync.labmatt.com` as a Resource
   pointing at the Newt site / `ingress-nginx` LoadBalancer, port 80 - same
   as `mattflix.labmatt.com` (see `jellyfin/ingress-block-metrics.yaml`).
   Pointing it at the `calibre-web-automated` service directly would
   bypass `ingress-books-sync.yaml`'s `/kobo/`-only path restriction and
   expose the full admin UI on this host.
3. Still in Pangolin, add two rules on `books-sync.labmatt.com`, scoped to
   path `/kobo/` (mirrors the existing `/metrics` block-path rule,
   inverted):
   - "Bypass Auth" - a Kobo can't complete an SSO redirect or hold a
     session cookie.
   - Rate limit - this path is the one thing not covered by SSO.
4. In CWA's admin UI (`books.labmatt.com`), enable Kobo Sync and generate
   the per-user sync token/URL.
5. On the Kobo device, point it at
   `https://books-sync.labmatt.com/kobo/<token>/`.
