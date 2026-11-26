#!/usr/bin/env python3
"""
Periodically re-searches Radarr/Sonarr items still on an x264-family codec,
waiting for an x265 release, using an increasing backoff interval per item
so the same title isn't re-queried against the trackers every single run.

Deliberately does NOT use Radarr/Sonarr's own `wanted/cutoff` endpoint --
that reflects each quality profile's `cutoffFormatScore` (10000 here),
which is effectively unreachable given the custom formats currently
configured, so it lists nearly everything as "cutoff unmet" forever,
including movies/episodes that are already x265. Instead this pulls the
full movie/episode list directly and filters on the actual codec in each
file's mediaInfo, which is the real signal we care about.

Reads/writes a small JSON state file (mounted from a PVC) tracking, per
instance and item id: when it was first seen, when it was last checked, and
the current backoff interval. Items that fall out of the x264 candidate
list (upgraded, or removed from the library) are pruned from state
automatically.

Two things temper how aggressively a newly-discovered item gets searched:

- A minimum delay (MIN_FIRST_SEARCH_DELAY_HOURS) after an item first appears
  in the candidate list before its very first search fires, since it was
  likely just grabbed moments ago and nothing new has had time to appear.
- Older content (AGE_THRESHOLD_DAYS, based on release year for movies / air
  date for episodes) starts further along the backoff ladder rather than at
  day 1, since new encodes are far less likely to appear for old titles than
  for recent ones -- backed by what we actually observed doing this by hand.

Also re-searches missing items: monitored movies that are available but have
no file, and monitored episodes that have aired but have no file. Radarr and
Sonarr search only once on add and never retry, so a failed first search
(e.g. an indexer outage) otherwise leaves the request stuck forever. Missing
items always start at BACKOFF_DAYS[0]. Each run reserves up to MISSING_SLOTS
of the batch for missing items and gives the rest to upgrades, so a pile of
never-found items can't starve upgrades; unused slots go to the other side.

Each run searches at most BATCH_CAP items total across the whole stack,
prioritizing whichever items are most overdue.
"""
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import date, datetime, timezone

STATE_PATH = "/state/state.json"
BATCH_CAP = int(os.environ.get("BATCH_CAP", "2"))
BACKOFF_DAYS = [int(x) for x in os.environ.get("BACKOFF_DAYS", "1,3,9,30,90,360").split(",")]
MIN_FIRST_SEARCH_DELAY_HOURS = int(os.environ.get("MIN_FIRST_SEARCH_DELAY_HOURS", "2"))
AGE_THRESHOLD_DAYS = int(os.environ.get("AGE_THRESHOLD_DAYS", "365"))
# Must be one of the values in BACKOFF_DAYS -- old content starts here
# instead of at BACKOFF_DAYS[0].
OLD_CONTENT_START_INTERVAL = int(os.environ.get("OLD_CONTENT_START_INTERVAL", "30"))
# Max slots per run reserved for missing items; upgrades get the rest, and either side takes unused slots.
MISSING_SLOTS = int(os.environ.get("MISSING_SLOTS", "1"))

INSTANCES = [
    {
        "key": "radarr-standard",
        "kind": "radarr",
        "url": os.environ["RADARR_URL"],
        "api_key": os.environ["RADARR_API_KEY"],
    },
    {
        "key": "sonarr-standard",
        "kind": "sonarr",
        "url": os.environ["SONARR_URL"],
        "api_key": os.environ["SONARR_API_KEY"],
    },
    {
        "key": "sonarr-anime",
        "kind": "sonarr",
        "url": os.environ["SONARR_ANIME_URL"],
        "api_key": os.environ["SONARR_ANIME_API_KEY"],
    },
]


def api_get(base_url, api_key, path):
    req = urllib.request.Request(f"{base_url}{path}", headers={"X-Api-Key": api_key})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8", errors="ignore"))


def api_post(base_url, api_key, path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        f"{base_url}{path}",
        data=data,
        headers={"X-Api-Key": api_key, "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8", errors="ignore"))


def load_state():
    if os.path.exists(STATE_PATH):
        with open(STATE_PATH) as f:
            return json.load(f)
    return {}


def save_state(state):
    tmp = STATE_PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=2, sort_keys=True)
    os.replace(tmp, STATE_PATH)


def next_interval(current_days):
    """Advance to the next rung in the backoff ladder, capping at the last one."""
    try:
        idx = BACKOFF_DAYS.index(current_days)
        return BACKOFF_DAYS[min(idx + 1, len(BACKOFF_DAYS) - 1)]
    except ValueError:
        return BACKOFF_DAYS[-1]


def starting_interval(age_days, missing):
    """Where a never-before-searched item enters the backoff ladder: day 1
    for recent or missing content, further along for old upgrades."""
    if not missing and age_days is not None and age_days > AGE_THRESHOLD_DAYS:
        return OLD_CONTENT_START_INTERVAL
    return BACKOFF_DAYS[0]


def parse_datetime(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def parse_date(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).date()
    except ValueError:
        return None


def is_x264_family(codec):
    if not codec:
        return False
    codec = codec.lower()
    return codec in ("x264", "h264", "avc") or "xvid" in codec


def get_movie_candidates(inst, today):
    """Radarr: full movie list, filtered to monitored movies that are either
    missing (available, no file) or have a file still on an x264-family codec."""
    items = []
    movies = api_get(inst["url"], inst["api_key"], "/api/v3/movie")
    for m in movies:
        if not m.get("monitored"):
            continue
        year = m.get("year")
        age_days = (today - date(year, 1, 1)).days if year else None
        mf = m.get("movieFile")
        if not mf:
            if m.get("isAvailable"):
                items.append({"id": m["id"], "title": m.get("title", "?"), "age_days": age_days, "missing": True})
            continue
        codec = mf.get("mediaInfo", {}).get("videoCodec", "")
        if not is_x264_family(codec):
            continue
        items.append({"id": m["id"], "title": m.get("title", "?"), "age_days": age_days, "missing": False})
    return items


def get_episode_candidates(inst, now):
    """Sonarr: per-series episode + episodefile join, filtered to monitored
    episodes that are either missing (aired, no file) or have a file still on
    an x264-family codec."""
    today = now.date()
    items = []
    series_list = api_get(inst["url"], inst["api_key"], "/api/v3/series")
    for s in series_list:
        if not s.get("monitored"):
            continue
        sid = s["id"]
        episodes = api_get(inst["url"], inst["api_key"], f"/api/v3/episode?seriesId={sid}")
        files = api_get(inst["url"], inst["api_key"], f"/api/v3/episodefile?seriesId={sid}")
        files_by_id = {f["id"]: f for f in files}
        for ep in episodes:
            if not ep.get("monitored"):
                continue
            air_date = parse_date(ep.get("airDateUtc") or ep.get("airDate"))
            age_days = (today - air_date).days if air_date else None
            title = f"{s.get('title', '?')} S{ep.get('seasonNumber', '?')}E{ep.get('episodeNumber', '?')}"
            if not ep.get("hasFile"):
                aired = parse_datetime(ep.get("airDateUtc"))
                if aired is not None and aired < now:
                    items.append({"id": ep["id"], "title": title, "age_days": age_days, "missing": True})
                continue
            ef = files_by_id.get(ep.get("episodeFileId"))
            if not ef:
                continue
            codec = ef.get("mediaInfo", {}).get("videoCodec", "")
            if not is_x264_family(codec):
                continue
            items.append({"id": ep["id"], "title": title, "age_days": age_days, "missing": False})
    return items


def get_candidates(inst, now):
    if inst["kind"] == "radarr":
        return get_movie_candidates(inst, now.date())
    return get_episode_candidates(inst, now)


def trigger_search(inst, ids):
    if inst["kind"] == "radarr":
        api_post(inst["url"], inst["api_key"], "/api/v3/command", {"name": "MoviesSearch", "movieIds": ids})
    else:
        api_post(inst["url"], inst["api_key"], "/api/v3/command", {"name": "EpisodeSearch", "episodeIds": ids})


def main():
    state = load_state()
    now = datetime.now(timezone.utc)
    today = now.date()

    # (key, state_id, title, age_days, missing, priority) -- higher priority =
    # more urgent. Never-searched-yet items that have cleared the floor rank
    # above the regular backlog (10**6 comfortably exceeds any realistic
    # overdue_by). Missing and upgrade items are split into separate slots below.
    due = []
    for inst in INSTANCES:
        key = inst["key"]
        state.setdefault(key, {})
        try:
            candidates = get_candidates(inst, now)
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
            print(f"[{key}] failed to fetch candidates: {e}", file=sys.stderr)
            continue

        candidate_ids = set()
        for item in candidates:
            # Missing items get their own state key so a later x264 file
            # starts a fresh upgrade backoff.
            item_id = f"missing:{item['id']}" if item["missing"] else str(item["id"])
            candidate_ids.add(item_id)
            entry = state[key].get(item_id)

            if entry is None:
                state[key][item_id] = {
                    "first_seen": now.isoformat(),
                    "last_checked": None,
                    "interval_days": None,
                }
                entry = state[key][item_id]

            if entry["last_checked"] is None:
                first_seen = datetime.fromisoformat(entry["first_seen"])
                age_hours = (now - first_seen).total_seconds() / 3600
                if age_hours >= MIN_FIRST_SEARCH_DELAY_HOURS:
                    due.append((key, item_id, item["title"], item["age_days"], item["missing"], 10**6 + age_hours))
            else:
                last_checked = date.fromisoformat(entry["last_checked"])
                days_since = (today - last_checked).days
                overdue_by = days_since - entry["interval_days"]
                if overdue_by >= 0:
                    due.append((key, item_id, item["title"], item["age_days"], item["missing"], overdue_by))

        # Self-prune: anything no longer a candidate (downloaded, upgraded, or
        # removed from the library) doesn't need tracking anymore.
        for existing_id in list(state[key].keys()):
            if existing_id not in candidate_ids:
                del state[key][existing_id]

    due.sort(key=lambda x: -x[5])
    missing_due = [d for d in due if d[4]]
    upgrade_due = [d for d in due if not d[4]]
    batch = missing_due[:MISSING_SLOTS]
    batch += upgrade_due[:BATCH_CAP - len(batch)]
    batch += missing_due[MISSING_SLOTS:MISSING_SLOTS + BATCH_CAP - len(batch)]

    if not batch:
        print("Nothing due for search right now.")
        save_state(state)
        return

    by_instance = {}
    for key, item_id, title, age_days, missing, _ in batch:
        by_instance.setdefault(key, []).append((item_id, title, age_days, missing))

    for inst in INSTANCES:
        key = inst["key"]
        items = by_instance.get(key)
        if not items:
            continue
        ids = [int(i.removeprefix("missing:")) for i, _, _, _ in items]
        titles = ", ".join(t + (" (missing)" if m else "") for _, t, _, m in items)
        print(f"[{key}] searching {len(ids)} item(s): {titles}")
        try:
            trigger_search(inst, ids)
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
            print(f"[{key}] search command failed, will retry next run: {e}", file=sys.stderr)
            continue
        for item_id, _, age_days, missing in items:
            prev_interval = state[key][item_id]["interval_days"]
            new_interval = next_interval(prev_interval) if prev_interval is not None else starting_interval(age_days, missing)
            state[key][item_id]["last_checked"] = today.isoformat()
            state[key][item_id]["interval_days"] = new_interval

    save_state(state)
    print(f"Done. Searched {len(batch)} item(s) across the stack.")


if __name__ == "__main__":
    main()
