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
It also needs three Secrets of its own. These commands copy each key from the app's config, so the key never lands in shell history:
```bash
for app in radarr-portuguese sonarr-portuguese; do
  kubectl exec -n downloads-standard deploy/$app -c $app -- \
    sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' /config/config.xml | tr -d '\n' |
    kubectl create secret generic $app-api-key -n downloads-standard --from-file=api-key=/dev/stdin
done

kubectl exec -n downloads-standard deploy/sabnzbd-standard -- \
  sed -n 's/^api_key = //p' /config/sabnzbd.ini | tr -d '\n' |
  kubectl create secret generic sabnzbd-api-key -n downloads-standard --from-file=api-key=/dev/stdin
```
