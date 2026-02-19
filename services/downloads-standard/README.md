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
