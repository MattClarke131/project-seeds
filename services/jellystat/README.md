# Jellystat

Jellystat is a statistics and watch history tracker for Jellyfin, backed by PostgreSQL.

Available at: https://jellystat.labmatt.com

## Bootstrap

### Step 1: Generate JWT Secret
```bash
kubectl create secret generic jellystat-jwt \
  --from-literal=JWT_SECRET=$(openssl rand -base64 32) \
  --namespace jellyfin
```

### Step 2: Apply Manifests
```bash
kubectl apply -f services/jellystat/
```

### Step 3: Generate Jellyfin API Key
In Jellyfin, go to Dashboard → API Keys → + and create a key named "Jellystat".

### Step 4: Complete Setup
Navigate to https://jellystat.labmatt.com and complete the setup wizard using:
- **Jellyfin URL:** `http://jellyfin.jellyfin.svc.cluster.local:8096`
- **API Key:** from Step 3

## Dependencies
- PostgreSQL (`jfstat` database in the `database` namespace via CloudNativePG)
- `postgres-app` secret mirrored to `jellyfin` namespace via Reflector
