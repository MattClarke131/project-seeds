# agentgateway

[agentgateway](https://agentgateway.dev) is the doorman between agents and MCP servers. It answers one question on every request: may this agent call this tool? This is milestone 1 of the agent platform: static API keys in front of jellyfin-mcp. A token minter replaces the static keys in milestone 3.

## Layout
- **`controller/`**: namespace, both Helm charts (CRDs, then controller) and the controller's network policy. Flux Kustomization `agentgateway`, which waits for `envoy-gateway`.
- **`gateway/`**: the `mcp` Gateway, its proxy settings, the API key policy, one file per MCP backend, and the proxy's network policy. Flux Kustomization `agentgateway-gateway`, which waits for the first so the CRDs exist.

## What it enforces
- **No key, no entry:** every request needs a key from `agentgateway-api-keys`, or it gets a 401.
- **Tool allowlist per key role:** a backend's policy lists the tools each key `role` may use. Unlisted tools are hidden from `tools/list`, and calling one fails as if it did not exist.
- **Credential swap:** the agent's key is stripped, and the backend's own token is added. Agents never hold backend credentials.
- **Only path in:** jellyfin-mcp accepts traffic only from the proxy (and kubelet probes).

| Path | Backend | Roles |
| --- | --- | --- |
| `/jellyfin/mcp` | jellyfin-mcp | `jellyfin-reader`: every read-only tool except `jellyfin_libraries`, which 403s for its non-admin user |

## Gateway API version
The controller (v1.7.0) is built against Gateway API v1.7.0-rc.3, but the cluster's CRDs come from envoy-gateway at v1.6.1. They work together: every kind the controller watches is served at the version it expects, and the two kinds new in v1.7 (XBackend, InferencePool) are off by default. Check again before bumping either chart:

```bash
kubectl get crd gateways.gateway.networking.k8s.io -o yaml | grep bundle-version
```

## Prerequisites (Manual Secrets)
Create these in `agents` **before** merging; `agentgateway-gateway` waits for the Gateway to become ready.

```bash
kubectl create namespace agents
```

1. **API keys.** Two Secrets per key:
   - `agentgateway-api-keys` holds only hashes. The gateway reads it, and it can grow to one entry per agent. Each entry's `metadata.role` picks the tools that key may use.
   - `<agent>-gateway-key` holds the raw key, for the agent that sends it.

   Keeping them apart means the gateway never holds a usable key. Nothing is printed:
   ```bash
   KEY=$(openssl rand -hex 32)
   HASH=$(printf '%s' "$KEY" | shasum -a 256 | cut -d' ' -f1)
   kubectl -n agents create secret generic agentgateway-api-keys \
     --from-literal=jellyfin-smoke="{\"keyHash\":\"sha256:$HASH\",\"metadata\":{\"role\":\"jellyfin-reader\"}}"
   kubectl -n agents create secret generic jellyfin-smoke-gateway-key \
     --from-literal=AGENTGATEWAY_KEY="$KEY"
   unset KEY HASH
   ```

2. **jellyfin-mcp's bearer token.** A copy of the Secret in the `jellyfin` namespace (Reflector is not installed):
   ```bash
   kubectl -n jellyfin get secret jellyfin-mcp-http-token -o json \
     | jq '{apiVersion, kind, type, data, metadata: {name: .metadata.name, namespace: "agents"}}' \
     | kubectl apply -f -
   ```
   When rotating the token, update both copies.

## Checking it
```bash
kubectl get gatewayclass agentgateway
kubectl -n agents get gateway,httproute,agentgatewaybackend,agentgatewaypolicy
kubectl -n agents get pods
kubectl -n agents port-forward svc/mcp 8080:8080
```

In another terminal:

```bash
KEY=$(kubectl -n agents get secret jellyfin-smoke-gateway-key -o jsonpath='{.data.AGENTGATEWAY_KEY}' | base64 -d)
URL=http://127.0.0.1:8080/jellyfin/mcp
H=(-H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream')
INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"check","version":"1"}}}'

# No key: expect 401
curl -s -o /dev/null -w '%{http_code}\n' -X POST $URL "${H[@]}" -d "$INIT"

# Valid key: expect the ten allowed tools and no jellyfin_libraries
SID=$(curl -s -D - -o /dev/null -X POST $URL "${H[@]}" -H "Authorization: Bearer $KEY" -d "$INIT" \
  | awk 'tolower($1)=="mcp-session-id:" {print $2}' | tr -d '\r')
A=("${H[@]}" -H "Authorization: Bearer $KEY" -H "Mcp-Session-Id: $SID")
curl -s -X POST $URL "${A[@]}" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}'
curl -s -X POST $URL "${A[@]}" -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | sed 's/^data: //' | grep '^{' | jq -r '.result.tools[].name'

# Unlisted tool: expect a JSON-RPC error, not a 403 from Jellyfin
curl -s -X POST $URL "${A[@]}" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"jellyfin_libraries","arguments":{}}}' \
  | sed 's/^data: //' | grep '^{' | jq .error
```

For an end-to-end agent run, see [agents/jellyfin-smoke](../../../agents/jellyfin-smoke/README.md).
