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
4. Watch for an apply error like `Resource already exists: <domain> in
   org <org>` - it means the resource's key in `blueprint.yaml` doesn't
   match its real niceId (see schema gotchas below). The apply is
   rejected outright when this happens; nothing gets touched, so it's
   safe, but it means the key needs fixing before retrying.
5. **If the paste touched more than one resource's target**, restart
   Newt immediately, even if nothing looks broken yet:
   ```bash
   kubectl rollout restart deployment/newt -n tunnel
   ```
   A single-resource apply doesn't need this - verify with curl first
   (next step) and only restart if something's actually broken.
6. Verify by curling the actual domain, not the dashboard's health badge:
   ```bash
   curl -o /dev/null -w "%{http_code}\n" https://<domain>
   ```
   The health badge can show a stale/misleading status (e.g. "Unhealthy
   99.8%") that doesn't reflect current reality - it's not a health check
   that's continuously refreshing feedback, just a frozen record from
   whenever it last actually ran.

### What actually causes the 503s (confirmed by direct testing)

The first real apply of the consolidated `jellyfin`/`seerr`/`pangolin-test`
blueprint caused `mattflix.labmatt.com` and `gimme.labmatt.com` to both
503 until `kubectl rollout restart deployment/newt -n tunnel` was run.
Two theories were tested directly before landing on the real cause:

- **"Any target change reassigns a port and the live-update path doesn't
  propagate it."** Disproven: isolated single-resource applies with a
  genuinely different target (hostname-only, then hostname+port
  together, against `pangolin-test`) live-updated cleanly with zero
  downtime every time.
- **"`jellyfin`'s and `seerr`'s keys were wrong"** (written as the
  display names `jellyfin`/`seerr` instead of their real niceIds,
  `growing-roses-rain-frog`/`organic-nile-monitor`). This *was* a real
  bug - fixed in `blueprint.yaml` - but a single-resource apply with a
  bad key just fails atomically with `Resource already exists: <domain>`
  and touches nothing, so it doesn't explain the original 503s by
  itself.

**Confirmed root cause: applying more than one resource's target in the
same paste breaks Newt's live-update path for all but one of them.**
Reproduced directly - applying the corrected (correctly-keyed)
`jellyfin` + `seerr` + `pangolin-test` blueprint together immediately
502'd `mattflix.labmatt.com`, and the Newt logs showed why:
`Replacing existing target with ID 1` and `...with ID 2` both fired, but
only one `Started tcp proxy to ...` line followed - the second target's
proxy handler never came back up. A restart fixed it immediately, same
as originally. `pangolin-test` alone (single resource, values genuinely
different) never showed this; only a same-paste multi-target apply does.

**Practical upshot:** treat a restart as required whenever a paste
touches **more than one resource's target in the same apply**. A
single-resource apply - even with a real target diff - does not need
one; verify with curl first and only restart if something's actually
broken. Always double-check a resource's key against its real niceId
before applying, especially for anything not originally created via a
blueprint (see schema gotchas below) - a bad key at least fails safely
on its own, but there's no reason to rely on that when it's just as
easy to get the key right upfront.

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
