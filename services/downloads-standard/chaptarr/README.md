# chaptarr

Book acquisition (ebooks + audiobooks), successor to the retired Readarr.
See GitHub issue #18 for why Chaptarr was picked over Librarr/LazyLibrarian.

Manual setup in the UI (`chaptarr.labmatt.com`), same pattern as the other
*arr apps - none of this is expressed in YAML:

1. Settings -> Download Clients: add the existing qBittorrent
   (`qbittorrent-vpn.downloads-standard.svc.cluster.local:8080`).
2. Settings -> Indexers: sync from the existing Prowlarr instance.
3. Settings -> Media Management: add two root folders, and under Completed
   Download Handling enable "Use Hardlinks instead of Copy" (same setting
   Radarr/Sonarr already use) so imports from qBittorrent's download folder
   land here for free.
   - `/media/books`, type eBook, default for ebooks.
   - `/media/audiobooks`, type Audio, default for audiobooks. AudioBookshelf
     reads this folder directly (see `../audiobookshelf/README.md`).

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
4. Click "Test" to confirm it's wired up correctly (exits 0, no
   filesystem changes). Trigger a real import to confirm end-to-end.

The script reads `$Chaptarr_AddedBookPaths` (pipe-separated import paths),
confirmed against `CustomScript.cs` in the Chaptarr source
(`Chaptarr/chaptarr@main`) - capitalized with a `Chaptarr_` prefix, unlike
Readarr's lowercase `readarr_addedbookpaths` this was originally modeled
on.

## Notifying AudioBookshelf (issue #193)

Audiobooks need no script: Chaptarr saves them straight into
`/media/audiobooks`, which ABS reads. The native AudioBookShelf connection
just tells ABS to rescan after each import, so books appear without waiting
for ABS's hourly scheduled scan.

1. In ABS, Settings -> API Keys: create a key named `chaptarr` on the root
   user, with no expiry. Starting a library scan requires an admin.
2. Settings -> Connect -> add AudioBookShelf:
   - Host `audiobookshelf.downloads-standard.svc.cluster.local`, port `80`,
     SSL off, and the API key.
   - Root folder mappings: Audio `/media/audiobooks` -> ABS `/audiobooks`;
     eBook `/media/books` -> None.
3. Trigger on "On Release Import", "On Rename", and "On Book File Delete".
