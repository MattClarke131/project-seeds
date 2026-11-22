# jellyfin-mcp

Model Context Protocol (MCP) server for Jellyfin (`ghcr.io/jaredtrent/jellyfin-mcp`), exposed over Streamable HTTP as an internal `ClusterIP`-only Service (no Ingress). Deployed in `--read-only` mode as defense-in-depth alongside `agentgateway` (see #447).

## Prerequisites (Manual Secrets)

Create both Secrets in the `jellyfin` namespace **before** merging (the `jellyfin` Flux Kustomization has `wait: true`). Secrets are split by trust boundary so `agentgateway` never receives the Jellyfin credential:

1. **Jellyfin user token (never leaves the `jellyfin` namespace):**
   Create a dedicated non-admin Jellyfin user (e.g., `mcp-reader` with library read access, admin/deletion/remote-control disabled), obtain its persistent `AccessToken` via `POST /Users/AuthenticateByName`, and store it:
   ```bash
   kubectl -n jellyfin create secret generic jellyfin-mcp-credentials \
     --from-literal=JELLYFIN_API_KEY="<non-admin-access-token>"
   ```

2. **Internal HTTP bearer token (shared with `mcp-gateway` via Reflector):**
   `jellyfin-mcp` requires a bearer token whenever listening beyond `localhost`:
   ```bash
   kubectl -n jellyfin create secret generic jellyfin-mcp-http-token \
     --from-literal=HTTP_TOKEN="$(openssl rand -hex 32)"

   kubectl -n jellyfin annotate secret jellyfin-mcp-http-token \
     reflector.v1.k8s.emberstack.com/reflection-allowed=true \
     reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces=mcp-gateway \
     --overwrite
   ```

## Verification

Forward the internal Service locally and verify `/health` and `tools/list`:

```bash
kubectl -n jellyfin port-forward svc/jellyfin-mcp 8080:8080
```

In another terminal:

```bash
curl -sS http://127.0.0.1:8080/health
# Expected: {"status":"ok"}

HTTP_TOKEN=$(kubectl -n jellyfin get secret jellyfin-mcp-http-token -o jsonpath='{.data.HTTP_TOKEN}' | base64 -d)
curl -sS -X POST http://127.0.0.1:8080/mcp \
  -H "Authorization: Bearer $HTTP_TOKEN" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"verify","version":"1.0"}}}'
```
