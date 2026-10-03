# Media Folder Layout
All apps mount the `media-standard` PVC at `/media` (NFS: `sleipnir/media-standard`), so hardlinks work between downloads and libraries.

```
/media
├── downloads
│   ├── qbittorrent/{completed,incomplete}
│   └── sabnzbd/{complete,incomplete}
├── tv, tv-portuguese      # Sonarr libraries
├── anime                  # Sonarr anime library
├── movies, movies-portuguese  # Radarr libraries
└── books, books-ingest, audiobooks  # Chaptarr / CWA
```

- **Root folders:** Servarr apps only accept paths registered in their UI (Settings -> Media Management -> Root Folders). The registration lives in each app's database, not in git.
- **sonarr-standard:** `/media/tv` and `/media/anime`. Seerr routes anime requests to `/media/anime` on this instance, so requests fail with "Root folder does not exist" without it.
- **radarr-standard:** `/media/movies`.
- **Portuguese instances:** `/media/tv-portuguese` (sonarr-portuguese) and `/media/movies-portuguese` (radarr-portuguese).
- **qBittorrent:** saves to `/media/downloads/qbittorrent/completed`, with temp files in `incomplete`.
- **sabnzbd:** uses `/media/downloads/sabnzbd/{complete,incomplete}`.

# Usenet Providers
https://www.uzantoreto.com/en/retention/alt.binaries.boneless/

## Configuring sabnzbd
1. Forward the sabnzbd port to your local machine:
```bash
kubectl port-forward -n downloads-standard svc/sabnzbd-standard 9999:8080
```
2. Open http://localhost:9999 in your browser

3. Go through setup wizard

4. Configure download directories
```bash
truenas_admin@truenas:~$ mkdir -p /mnt/downloads/<host_name>/media-standard/downloads/sabnzbd/{,in}complete
```
```bash
truenas_admin@truenas:~$ chown -R 1000:1000 /mnt/<host_name>/media-standard/downloads
```

## Running and Configuring Recyclarr
1. Create a secret for each servarr service
```bash
kubectl create secret generic sonarr-anime-api-key \
  --from-literal=api-key=YOUR_API_KEY_HERE \
  -n downloads-standard

kubectl create secret generic sonarr-api-key \
  --from-literal=api-key=YOUR_API_KEY_HERE \
  -n downloads-standard

kubectl create secret generic radarr-api-key \
  --from-literal=api-key=YOUR_API_KEY_HERE \
  -n downloads-standard
```

2. Apply recyclar config
```bash
kubectl apply -f recyclarr/
```

3. Trigger a manual sync
```bash
kubectl create job --from=cronjob/recyclarr recyclarr-manual-sync-anime -n downloads-standard
```

4. Watch the logs
```bash
kubectl logs -n downloads-standard -l job-name=recyclarr-manual-sync-anime -f
```
