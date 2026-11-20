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

## exportarr API keys
`exportarr/` exports Prometheus metrics for the Downloads Grafana dashboard (#165).
It reuses `radarr-api-key`, `sonarr-api-key` and `bazarr-secret` from above, plus Prowlarr's key in `cross-seed-secrets`.
It also needs three Secrets of its own. These commands copy each key from the app's config, so the key never lands in shell history or output.
Each step stops if the read fails or finds no key, rather than creating an empty Secret:
```bash
# Usage: make_key_secret <secret-name> <command that prints the key...>
make_key_secret() {
  name=$1; shift
  key=$("$@") || { echo "reading key for $name failed" >&2; return 1; }
  [ -n "$key" ] || { echo "no key found for $name" >&2; return 1; }
  printf %s "$key" |
    kubectl create secret generic "$name" -n downloads-standard --from-file=api-key=/dev/stdin
}

for app in radarr-portuguese sonarr-portuguese; do
  make_key_secret "$app-api-key" kubectl exec -n downloads-standard "deploy/$app" -c "$app" -- \
    sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' /config/config.xml
done

make_key_secret sabnzbd-api-key kubectl exec -n downloads-standard deploy/sabnzbd-standard -- \
  sed -n 's/^api_key = //p' /config/sabnzbd.ini
```

## Unpackerr
`unpackerr/` extracts archived torrent downloads (RAR, zip, 7z) that Sonarr and Radarr would otherwise leave stuck in the queue with "Found archive file, might need to be extracted" (#169).
It deletes the extracted copy 5 minutes after import. The original archive stays so the torrent keeps seeding.
- **Secrets:** none of its own. It reuses `sonarr-api-key`, `sonarr-portuguese-api-key`, `radarr-api-key` and `radarr-portuguese-api-key`.
- **Scope:** torrents only. SABnzbd extracts its own downloads. sonarr-anime is skipped (#167).
- **Web UI:** off. Unpackerr v1 starts one on port 5656 by default; `UN_WEBSERVER_LISTEN_ADDR=""` disables it.
- **Logs:** `kubectl logs -n downloads-standard deploy/unpackerr`. Queue summaries appear only while something is in flight.
