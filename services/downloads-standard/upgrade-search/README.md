# upgrade-search

A CronJob that periodically re-searches Radarr/Sonarr items still below
their quality profile's cutoff (i.e. still on x264, waiting for an x265
release to show up), instead of relying on someone to trigger that search
by hand.

## How it works

Every 4 hours it pulls the full movie/episode list directly from Radarr
(`radarr-standard`), Sonarr (`sonarr-standard`), and Sonarr Anime
(`sonarr-anime`) and filters for monitored items whose current file is
still on an x264-family codec, picks up to `BATCH_CAP` of the
most-overdue candidates across the whole stack, and fires a search for
them. State (last checked, current backoff interval) is kept in a small
JSON file on the `upgrade-search-state` PVC so runs aren't re-querying the
same items every time — see the docstring in `upgrade_search.py` for the
full backoff design (age-based starting point, minimum delay before an
item's first search, and the backoff ladder itself).

Deliberately does **not** use Radarr/Sonarr's own `wanted/cutoff`
endpoint — testing showed it reflects each quality profile's
`cutoffFormatScore` (10000 here), which is effectively unreachable given
the custom formats currently configured, so it lists nearly everything as
"cutoff unmet" forever, including movies/episodes that are already x265.
Filtering on the file's actual `mediaInfo.videoCodec` directly, pulled
from Radarr/Sonarr's own data (not the trackers), is the correct signal
and was verified against known-upgraded and known-still-x264 titles
before this was deployed.

Deliberately excludes `radarr-portuguese` / `sonarr-portuguese` — those
don't have any x264/x265 scoring configured (see
`../recyclarr/configmap.yaml`), so there's nothing for this job to act on
for them yet.

## Files

- `upgrade_search.py` — the actual script. This is the source of truth;
  edit this file, not `configmap.yaml` directly.
- `configmap.yaml` — generated from `upgrade_search.py` (see below).
  Regenerate it any time you change the script.
- `pvc.yaml` — small persistent volume for the backoff state file.
- `cronjob.yaml` — the schedule and runtime config (batch size, backoff
  values, etc. — all overridable via env vars without touching the
  script).

## Regenerating the ConfigMap after editing the script

```bash
kubectl create configmap upgrade-search-script -n downloads-standard \
  --from-file=upgrade_search.py=upgrade_search.py \
  --dry-run=client -o yaml > configmap.yaml
```

Then tidy the output: it currently emits `data`/`kind`/`metadata` out of
the repo's usual field order and includes a stray `creationTimestamp:
null` — strip that line and reorder to `apiVersion`, `kind`, `metadata`,
`data` to match the rest of this repo before committing.

## Deploying

```bash
kubectl apply -f pvc.yaml -f configmap.yaml -f cronjob.yaml
```

Uses the same `radarr-api-key`, `sonarr-api-key`, and
`sonarr-anime-api-key` secrets as `../recyclarr` — no new secrets needed.

## Tuning

All the knobs are env vars on the container in `cronjob.yaml`:

| Env var | Default | Meaning |
|---|---|---|
| `BATCH_CAP` | `2` | Max items searched per run, across the whole stack |
| `BACKOFF_DAYS` | `1,3,9,30,90,360` | Recheck ladder; caps at the last value once reached |
| `MIN_FIRST_SEARCH_DELAY_HOURS` | `2` | Minimum time an item must sit in the cutoff-unmet list before its first search |
| `AGE_THRESHOLD_DAYS` | `365` | Content older than this starts at `OLD_CONTENT_START_INTERVAL` instead of day 1 |
| `OLD_CONTENT_START_INTERVAL` | `30` | Must be one of the values in `BACKOFF_DAYS` |

At 2 items/run × 6 runs/day = 12 searches/day max across the whole stack.
Checked against indexer limits in Prowlarr at the time this was built:
DrunkenSlug (950 queries/day), IPTorrents (300 queries/day, 50 grabs/day —
the tightest constraint), YUSCENE (unconfigured/unlimited). 12/day leaves
wide margin on all three, alongside the existing RSS Sync traffic Radarr/
Sonarr already generate independently of this job.
