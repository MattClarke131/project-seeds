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
4. Click "Test" once wired up, then check the pod logs
   (`kubectl logs -n downloads-standard deploy/chaptarr`) for the script's
   `hardlink-to-cwa-ingest:` output.

The script reads `$chaptarr_addedbookpaths` (pipe-separated import paths),
modeled on Readarr's undocumented `readarr_addedbookpaths` - **this env var
name is unverified against a running Chaptarr instance.** If step 4 logs
"chaptarr_addedbookpaths is unset", run `env | grep -i chaptarr` from the
Custom Script instead (temporarily swap the script's Path in Chaptarr's UI,
or exec into the container after a live import) to find the actual name(s)
Chaptarr passes, then update `configmap-hardlink-script.yaml` to match.
