# chaptarr

Book acquisition (ebooks + audiobooks), successor to the retired Readarr.
See GitHub issue #18 for why Chaptarr was picked over Librarr/LazyLibrarian.

Manual setup in the UI (`chaptarr.labmatt.com`), same pattern as the other
*arr apps - none of this is expressed in YAML:

1. Settings -> Download Clients: add the existing qBittorrent
   (`qbittorrent-vpn.downloads-standard.svc.cluster.local:8080`).
2. Settings -> Indexers: sync from the existing Prowlarr instance.
3. Settings -> Media Management: add a root folder at `/media/books`, and
   under Completed Download Handling enable "Use Hardlinks instead of
   Copy" (same setting Radarr/Sonarr already use) so imports from
   qBittorrent's download folder land here for free.

## Feeding CWA (issue #17)

CWA watches `/media/books-ingest` (a subpath of the same `media-standard`
PVC as Chaptarr's root folder) and auto-converts/imports anything dropped
there. Chaptarr doesn't know about CWA, so a Connect custom script bridges
the two - same shape as Radarr/Sonarr hardlinking a completed download into
their library, one hop further:

1. Settings -> Connect -> add a Custom Script.
2. Path: `/scripts/hardlink-to-cwa-ingest.sh` (from the
   `chaptarr-hardlink-script` ConfigMap).
3. Trigger on "On Release Import", "On Upgrade", and "On Book File Delete".
   Leave "On Book File Delete For Upgrade" off: upgrades already pass the
   replaced files to the import event.
4. Click "Test" to confirm it's wired up correctly (exits 0, no
   filesystem changes). Trigger a real import to confirm end-to-end.

## Feeding AudioBookshelf (issue #193)

The same script splits imports by extension:

- **Ebooks** are hardlinked into `/media/books-ingest` for CWA, which deletes
  them after processing.
- **Audiobooks** (mp3/m4a/m4b/flac/ogg/opus/wav/aac) are hardlinked into
  `/media/audiobooks`, a permanent mirror of Chaptarr's layout that ABS
  reads. Upgrades and file deletes remove the old link, so ABS never shows
  stale duplicates.

The filename still says "cwa-ingest" so the live Connect entry keeps working.

## Script environment variables

Confirmed against `CustomScript.cs` in the Chaptarr source
(`Chaptarr/chaptarr@main`). All are capitalized with a `Chaptarr_` prefix,
unlike Readarr's lowercase `readarr_*` this was originally modeled on.

- `Chaptarr_EventType`: `Download` (import or upgrade), `BookFileDelete`,
  `Test`, and others the script ignores.
- `Chaptarr_AddedBookPaths`: pipe-separated imported files.
- `Chaptarr_DeletedPaths`: pipe-separated files an upgrade replaced.
- `Chaptarr_BookFile_Path`: the deleted file on `BookFileDelete`.
