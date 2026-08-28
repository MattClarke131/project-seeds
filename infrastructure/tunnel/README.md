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

## Managing Resources via Blueprints

What's exposed through Pangolin (resources, targets, access rules) is
tracked in git as a [Blueprint](https://docs.pangolin.net/manage/blueprints):
`infrastructure/tunnel/blueprint.yaml`. This is the source of truth for
resource/rule config - the dashboard's Settings > Blueprints page is only
how it gets applied, never edited directly there for anything tracked in
this file.

**Workflow:**
1. Edit `blueprint.yaml` (or ask Claude to).
2. Review the diff like any other change.
3. Paste the file's contents into the dashboard's **Settings > Blueprints**
   page and apply. This step is deliberately manual - no scheduled apply,
   no CI trigger, no API call - so it can never silently clobber a change
   made through the dashboard.
4. **Restart the Newt connector immediately after every apply that
   touches a target**, even if nothing looks broken yet:
   ```bash
   kubectl rollout restart deployment/newt -n tunnel
   ```
5. Verify by curling the actual domain, not the dashboard's health badge:
   ```bash
   curl -o /dev/null -w "%{http_code}\n" https://<domain>
   ```
   The health badge can show a stale/misleading status (e.g. "Unhealthy
   99.8%") that doesn't reflect current reality - it's not a health check
   that's continuously refreshing feedback, just a frozen record from
   whenever it last actually ran.

### Why the Newt restart is required

Applying a Blueprint target update (even one that looks unchanged)
reassigns that target a new internal tunnel port on the Pangolin side.
Newt has a live-update path for this (`newt/tcp/add` / `newt/tcp/remove`
over its persistent websocket) that's supposed to make a restart
unnecessary - but in practice the reassignment doesn't propagate, and the
resource returns `503` externally even though the actual backend is
completely healthy. This isn't documented anywhere in Pangolin's docs and
looks like a real gap between the intended live-update path and what
`fosrl/pangolin`/`fosrl/newt` actually do on a Blueprint apply - not
something to code around further here, just something to expect and
correct for every time. A pod restart forces a full reconnect, which
picks up the current port assignment and fixes it in a few seconds.

### Blueprint schema gotchas

Learned the hard way, verified against `fosrl/pangolin` source
(`server/lib/blueprints/`) rather than assumed from docs:

- **A resource's key in `public-resources:` IS its niceId**, not a
  display name - it's matched directly against the DB. Using the wrong
  key creates a brand-new resource instead of updating the intended one.
  Get the real niceId from the resource's own settings page if it's not
  the plain name you'd expect.
- **A target's `site` field is matched against the site's niceId**, not
  its display name. Get this from the dashboard's Sites page.
- **Applying is a full overwrite of each block you specify, not a
  patch.** Omitting `healthcheck` on a target doesn't mean "leave it
  alone" - it disables whatever health check was already configured.
  Decide on purpose whether to include one.
- **`rules[].match` is lowercase** in the Blueprint YAML (`path`,
  `country`, ...) even though the DB/UI use uppercase for the same
  values - easy to transcribe wrong.
- **Rule `action` isn't a network-level allow/block.** `allow` skips all
  further checks including auth entirely; `deny` blocks outright;
  anything unmatched falls through to normal auth (e.g. SSO login) -
  not blocked, just gated behind sign-in.
