# calibre-web-automated

Ebook library + Kobo device sync. See GitHub issue #17 for the full design
(two-hostname split: `books.labmatt.com` tailnet-only admin UI,
`books-sync.labmatt.com` path-restricted Kobo sync via Pangolin).

1. In CWA's admin UI (`books.labmatt.com`), enable Kobo Sync and generate
   the per-user sync token/URL.
2. On the Kobo device, point it at
   `https://books-sync.labmatt.com/kobo/<token>/`.
