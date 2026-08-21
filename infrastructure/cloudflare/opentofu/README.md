# Cloudflare DNS

OpenTofu module for `labmatt.com` DNS. All records are `A`, DNS-only (not
proxied), grouped by target in `variables.tf`/`locals.tf`:

- a `*.labmatt.com` wildcard → `ingress_ip` (in-cluster ingress-nginx
  LoadBalancer on the k8sVNet). Any in-cluster service's `ingress.yaml`
  host just works against this - no DNS change needed, ever.
- `tunnel_hostnames` → `edge_proxy_ipv4` (Hetzner edge proxy running
  Pangolin; see [infrastructure/tunnel](../../tunnel))
- `headscale_hostnames` → `headscale_ipv4` (standalone VPS)
- `tailnet_assistant_hostnames` → `tailnet_assistant_ipv4` (snakAssistant
  over Tailscale)

The only reason a hostname needs an explicit record here is if it resolves
somewhere other than the wildcard's target - a service outside the
cluster, or on a different network path. Adding one of those just means
adding its hostname to the right set in `variables.tf`.

## One-Time Bootstrap

### 1. Create a Cloudflare API Token

Do **not** reuse the `cloudflare-api-token` k8s secret used by cert-manager
— that one only needs DNS edit for ACME challenges. Create a separate
token scoped just as tight for this module:

Cloudflare Dashboard → My Profile → API Tokens → Create Token → Custom Token

- Permissions: `Zone` → `DNS` → `Edit`, `Zone` → `Zone` → `Read`
- Zone Resources: `Include` → `Specific zone` → `labmatt.com`

Copy the token immediately into Bitwarden and `terraform.tfvars`.

### 2. Create `terraform.tfvars`

```hcl
cloudflare_api_token = "<token from step 1>"
edge_proxy_ipv4       = "<public_ipv4 output from infrastructure/tunnel/opentofu>"
```

`terraform.tfvars` is gitignored as it contains secrets.

### 3. Import existing records

Every hostname across the `*_hostnames` sets in `variables.tf`, plus the
`*.labmatt.com` wildcard, already exists as a manually created record.
Import each one before the first `apply` so it isn't destroyed/recreated:

```bash
tofu init

# get zone_id
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=labmatt.com" \
  -H "Authorization: Bearer <token>" | jq -r '.result[0].id')

# for each hostname, get the record id and import
for h in gimme mattflix pangolin \
         headscale \
         snakassistant; do
  RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$h.labmatt.com" \
    -H "Authorization: Bearer <token>" | jq -r '.result[0].id')
  tofu import "cloudflare_dns_record.record[\"$h\"]" "$ZONE_ID/$RECORD_ID"
done

WILDCARD_ID=$(curl -s -G "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  --data-urlencode "name=*.labmatt.com" \
  -H "Authorization: Bearer <token>" | jq -r '.result[0].id')
tofu import cloudflare_dns_record.wildcard "$ZONE_ID/$WILDCARD_ID"
```

Any hostname under `labmatt.com` not listed in one of the `*_hostnames`
sets resolves via the wildcard record instead — this module intentionally
does not enumerate every subdomain in the zone.

### 4. Verify plan is a no-op

```bash
tofu plan
```

Should show no changes. Cloudflare's "Auto" TTL round-trips as `1`, not a
literal duration — that's expected, not a bug. If it wants to touch
`comment` on `headscale`, check `record_comments` in `variables.tf`
matches what's in the dashboard.

## Removing a record

Delete the hostname from its `*_hostnames` set, `tofu plan` to confirm only
that record is marked for destroy, then `tofu apply`. It then falls back to
resolving via the wildcard record instead of disappearing from DNS
entirely — if you need it to stop resolving altogether, that's an
ingress-nginx/Host-header change, not a DNS change.
