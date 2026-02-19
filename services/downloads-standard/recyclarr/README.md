# Recyclarr

## Setup
1. Create a Kubernetes secret for your Radarr API key. Replace `YOUR_RADARR_API_KEY_HERE` with your actual API key.
```bash
kubectl create secret generic radarr-api-key \
  --from-literal=api-key=YOUR_RADARR_API_KEY_HERE \
  -n downloads-standard
```
