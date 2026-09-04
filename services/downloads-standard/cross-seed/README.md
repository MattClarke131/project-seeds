# cross-seed

Matches torrents already seeding in qBittorrent against other indexers
(via Prowlarr) and injects the match directly into qBittorrent, so
existing data earns ratio on additional trackers without re-downloading.

Runs in daemon mode: a 30-minute RSS cadence catches new torznab entries
quickly, plus a slower full-catalog search pass (`searchCadence: 1 day`)
to backfill matches for everything already seeding.

Not exposed via Ingress - it's only reached in-cluster today. Once
autobrr is deployed (#182), autobrr's announce webhook will call
cross-seed's HTTP API directly for near-instant matching, instead of
relying on the daily search pass.

## Secrets

Before applying the manifests, create `cross-seed-secrets`:

```sh
kubectl create secret generic cross-seed-secrets \
  --namespace downloads-standard \
  --from-literal=prowlarr-api-key='<Prowlarr API key, from Settings > General>' \
  --from-literal=qbittorrent-username='<qBittorrent WebUI username>' \
  --from-literal=qbittorrent-password='<qBittorrent WebUI password>' \
  --from-literal=cross-seed-api-key='<any random string - authenticates calls to cross-seed's own API>'
```

If qBittorrent's WebUI has no password set (local-subnet auth bypass),
leave `qbittorrent-username`/`qbittorrent-password` as empty strings
rather than omitting the keys - `config.js` always references both.

## Verifying

```sh
kubectl logs -n downloads-standard -l app=cross-seed -f
```

A manual full-catalog search can be triggered without waiting for
`searchCadence`:

```sh
kubectl exec -n downloads-standard deploy/cross-seed -- cross-seed search
```
