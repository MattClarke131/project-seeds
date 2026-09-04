# chaptarr

Book acquisition (ebooks + audiobooks), successor to the retired Readarr.
See GitHub issue #18 for why Chaptarr was picked over Librarr/LazyLibrarian.

Manual setup in the UI (`chaptarr.labmatt.com`), same pattern as the other
*arr apps - none of this is expressed in YAML:

1. Settings -> Download Clients: add the existing qBittorrent
   (`qbittorrent-vpn.downloads-standard.svc.cluster.local:8080`).
2. Settings -> Indexers: sync from the existing Prowlarr instance.
3. Settings -> Media Management: add a root folder at `/cwa-book-ingest`
   (the same PVC CWA watches as its ingest folder - see issue #17). Anything
   Chaptarr imports there gets picked up, converted, and moved into CWA's
   library automatically.
