# audiobookshelf

Audiobook server and player backend. See GitHub issue #193.

Chaptarr saves audiobooks into its Audio root folder, `/media/audiobooks`.
ABS mounts that folder read-only at `/audiobooks`. Chaptarr's AudioBookShelf
connection triggers a rescan after each import (see `../chaptarr/README.md`).

## First-time setup (`audiobooks.labmatt.com`)

1. Create the root user on first visit.
2. Libraries -> Add library: type **Books**, folder `/audiobooks`.
3. In that library's **Schedule** tab, enable an hourly scan. ABS's folder
   watcher uses inotify, which misses files Chaptarr writes from another pod
   over NFS.
4. Under Settings -> General, keep "Store covers with item" and "Store
   metadata with item" off (the defaults). The folder is read-only, so ABS
   must keep both in `/metadata`.

## Clients

- Android: official app from the Play Store.
- iOS: official app is TestFlight-only. ShelfPlayer, Plappa, and Absorb are
  third-party alternatives.
- Server address: `https://audiobooks.labmatt.com` (requires Tailscale).
