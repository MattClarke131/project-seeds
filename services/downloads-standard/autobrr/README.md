# autobrr

Watches IRC (and/or RSS) announces on private trackers and grabs matching
releases into qBittorrent much faster than Sonarr/Radarr's own search/RSS
polling. autobrr is a faster front door, not a replacement for their
matching logic - grabs still land in a category Sonarr/Radarr already scan,
so normal import/rename/upgrade handling still applies.

This deploy is just the running service. No trackers, filters, or the
qBittorrent download client are configured yet - that's done through the
WebUI per tracker (issue #182), not via manifest, since IRC connection
details and filter rules are one-time interactive setup, not something
that benefits from being in git.

## Database

State lives in the shared CNPG `postgres` cluster (database and role
`autobrr`), so trackers, filters, and IRC config are covered by its backups.
The role's password is a live-only Secret, created before merging:

```sh
kubectl create secret generic postgres-autobrr \
  --namespace database \
  --type kubernetes.io/basic-auth \
  --from-literal=username=autobrr \
  --from-literal=password="$(openssl rand -base64 32 | tr -d '\n')"
kubectl annotate secret postgres-autobrr -n database \
  reflector.v1.k8s.emberstack.com/reflection-allowed=true \
  reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces=downloads-standard
```

`pg_hba` in `infrastructure/kubernetes/database/postgres-cluster.yaml`
allows the `autobrr` role only into its own database and rejects it
everywhere else.

## First-time setup

1. Reach the WebUI at https://autobrr.labmatt.com and complete the
   onboarding wizard (creates the admin account in Postgres).
2. Settings > Clients: add qBittorrent
   (`http://qbittorrent-vpn.downloads-standard.svc.cluster.local:8080`).
3. Settings > Indexers: add one tracker at a time, only for trackers whose
   rules confirm third-party IRC announce bots are permitted. Roll out one
   tracker at a time and watch logs for a few days before adding the next.
4. Filters: scope conservatively (category, resolution, regex) per
   tracker before enabling - see issue #182 for the reasoning.

Once autobrr is grabbing correctly on its own, wire the cross-seed
announce-mode webhook (config posted as a comment on #182) as an
additional highest-priority filter action, so new grabs also cross-seed
within seconds instead of waiting on cross-seed's daily search sweep.

## Verifying

```sh
kubectl logs -n downloads-standard -l app=autobrr -f
```
