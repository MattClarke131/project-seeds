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

## First-time setup

1. Reach the WebUI at https://autobrr.labmatt.com and complete the
   onboarding wizard (creates the admin account, generates `config.toml`
   with a random session secret, persisted on `autobrr-config`).
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
