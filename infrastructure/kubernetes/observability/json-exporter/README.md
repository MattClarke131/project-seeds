# json-exporter

Scrapes Jellyfin's `/Sessions` endpoint for playback metrics.

The chart itself is Flux-managed (`helmrelease.yaml`). Only the Secret
below stays a manual step - it's excluded from the kustomization the same
as `renovate-github-token`/`newt-auth` are.

The `render-config` init container injects the API token at pod startup,
reading it from the `json-exporter-jellyfin-token` Secret and substituting
it into a templated config on a shared volume. To (re)create that Secret:

```zsh
echo -n "Jellyfin API key: "
read -s JF_KEY
echo
kubectl create secret generic json-exporter-jellyfin-token \
  --namespace=observability \
  --from-literal=token="$JF_KEY"
unset JF_KEY
```

Generate the API key itself via the Jellyfin admin dashboard:
Dashboard → API Keys → **+**.
