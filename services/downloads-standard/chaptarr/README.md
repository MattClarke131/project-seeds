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
3. Trigger on "On Release Import" and "On Upgrade".
4. Click "Test" to confirm it's wired up correctly (exits 0 without
   touching the filesystem - Chaptarr's own "Test" doesn't actually invoke
   custom scripts, so this only confirms the notification is saved, not
   that the script runs. Trigger a real import to confirm end-to-end.)

The script reads `$Chaptarr_AddedBookPaths` (pipe-separated import paths),
confirmed against `CustomScript.cs` in the Chaptarr source
(`Chaptarr/chaptarr@main`) - capitalized with a `Chaptarr_` prefix, unlike
Readarr's lowercase `readarr_addedbookpaths` this was originally modeled
on.
