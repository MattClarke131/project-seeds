# Pangolin Tunnel
https://docs.pangolin.net/self-host/quick-install

## Hetzner VPS Setup

### Configure DNS Records
1. Create A record for pangolin dashboard: `pangolin.labmatt.com` → Hetzner floating IP
2. Create A records for service endpoints: `mattflix.labmatt.com` → Hetzner floating IP
3. Set to DNS only (gray cloud) in Cloudflare

### Configure Firewall Rules
```bash
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 51820/udp
sudo ufw allow 21820/udp
sudo ufw enable
```

### Install Pangolin
```bash
curl -fsSL https://static.pangolin.net/get-installer.sh | bash
sudo ./installer
```

Follow prompts:
- Base domain: `labmatt.com`
- Dashboard subdomain: `pangolin.labmatt.com`
- Email: your email for Let's Encrypt
- Create admin account

### Configure Access Rules
1. Enable "Use Platform SSO"
2. Create Rule: "Block Access" "Path" "/metrics" (priority 1)
3. Create Rule: "Bypass Auth" "Country" "United States" (priority 2)

## Kubernetes Cluster Setup

### Deploy Newt Connector

1. Create namespace:
```bash
kubectl create namespace tunnel
```

2. Create secret with auth credentials (get from Pangolin dashboard):
```bash
kubectl create secret generic newt-auth \
  --from-literal=endpoint=https://pangolin.labmatt.com \
  --from-literal=id=<newt-id-from-dashboard> \
  --from-literal=secret=<newt-secret-from-dashboard> \
  -n tunnel
```

3. Deploy Newt (using manual deployment, Helm chart is broken):
```bash
kubectl apply -f infrastructure/kubernetes/tunnel/newt/deployment.yaml
```

4. Verify connection:
```bash
kubectl get pods -n tunnel
kubectl logs -n tunnel -l app=newt
```

Site should show "Online" in Pangolin dashboard.

## Version tracking

Pangolin/Gerbil/Traefik/Badger on the VPS aren't Flux-managed, so nothing
auto-upgrades them. `docker-compose.yml` and `badger-plugin-version.yml`
in this directory are mirrors of the real files on the VPS, kept only so
Renovate scans them and surfaces version drift (PRs / Dependency
Dashboard entries) - they are never applied by CI. When Renovate flags a
bump here:

1. SSH to the VPS (`root@<floating IP from opentofu output>`) and check
   `docker ps` for the versions actually running - the mirrors can lag if
   a manual upgrade wasn't reflected back here.
2. Upgrade for real via `docker compose down/pull/up -d` in `/root`,
   backing up `/root/config` first. Prefer incremental hops over large
   version jumps; check upstream release notes for breaking changes and
   required Badger/Newt versions first.
3. Update the versions in `docker-compose.yml` / `badger-plugin-version.yml`
   here to match, and merge the Renovate PR (or close it) accordingly.
