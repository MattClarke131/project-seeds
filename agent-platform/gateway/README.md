# Agent Platform Gateway (`agentgateway` M1)

Deploys `agentgateway` v1.7.0 into the `agents-test` namespace as the single internal Model Context Protocol (MCP) gateway in front of `jellyfin-mcp` (Milestone 1 of the Agent Platform design).

## Layout

- **`controller/`** (Flux Kustomization `agent-platform-gateway-controller`): `agents-test` namespace (`restricted` Pod Security), OCI `HelmRepository`, `agentgateway-crds` and `agentgateway` v1.7.0 `HelmRelease`s, and the controller's default-deny `CiliumNetworkPolicy`.
- **`config/`** (Flux Kustomization `agent-platform-gateway-config`): `AgentgatewayParameters` (`ClusterIP`, `restricted` PSA, resources), `Gateway` (`mcp-gateway`), `AgentgatewayBackend` (`jellyfin-mcp`), `HTTPRoute` (`/jellyfin/mcp`), `AgentgatewayPolicy`s (strict API key auth + fail-closed MCP tool allowlist), and the proxy's default-deny `CiliumNetworkPolicy`.
- **`../smoke-test/`**: Python (`uv`) LangGraph end-to-end smoke test agent.

## Prerequisites (Manual Secrets)

Create both Secrets in the `agents-test` namespace **before** merging (the Flux Kustomizations have `wait: true`). Reflector is not installed on `eye-of-michael`, so Secrets needed across namespaces are copied by hand.

1. **Copy `jellyfin-mcp`'s internal HTTP bearer token into `agents-test`:**
   `agentgateway` injects this token on upstream requests to `jellyfin-mcp` and never exposes it to agents.
   ```bash
   HTTP_TOKEN=$(kubectl -n jellyfin get secret jellyfin-mcp-http-token -o jsonpath='{.data.HTTP_TOKEN}' | base64 -d)
   kubectl -n agents-test create secret generic jellyfin-mcp-http-token \
     --from-literal=HTTP_TOKEN="$HTTP_TOKEN"
   ```

2. **Create the static M1 API keys Secret (`agentgateway-api-keys`):**
   Each key carries `metadata.allowed_tools`, evaluated in CEL alongside the backend's 10-tool allowlist (excluding `jellyfin_libraries`). M3 replaces this static Secret with an `extAuth` policy backed by the minter.
   ```bash
   AGENT_KEY="agw-$(openssl rand -hex 24)"
   echo "Save this agent API key: $AGENT_KEY"

   kubectl -n agents-test create secret generic agentgateway-api-keys \
     --from-literal=jellyfin-reader="$(cat <<EOF
   {
     "key": "$AGENT_KEY",
     "metadata": {
       "principal": "user:matt",
       "template": "media",
       "allowed_tools": [
         "jellyfin_analytics",
         "jellyfin_browse",
         "jellyfin_download_link",
         "jellyfin_get_item",
         "jellyfin_item_extras",
         "jellyfin_music",
         "jellyfin_people",
         "jellyfin_recommendations",
         "jellyfin_search",
         "jellyfin_tv_shows"
       ]
     }
   }
   EOF
   )"
   ```

## Network Policies

- **`agentgateway-controller`**: Ingress from `mcp-gateway` proxy pods (`9978/TCP` xDS), `host` (`9093/TCP` probes), and `observability/prometheus` (`9092/TCP`). Egress to `kube-apiserver` and `kube-dns` only.
- **`mcp-gateway-proxy`**: Ingress from `agents-test` pods (`8080/TCP`), `host` (health probes), and `observability/prometheus` (`15020/TCP`). Egress to controller (`9978/TCP`), `kube-dns`, and `jellyfin/jellyfin-mcp:8080` only.
- **`jellyfin/jellyfin-mcp`**: Accepts ingress only from `host` (kubelet probes) and `agents-test`'s `mcp-gateway` proxy pods on `8080/TCP`.

## Verification

Forward the ClusterIP gateway locally:
```bash
kubectl -n agents-test port-forward svc/mcp-gateway 8080:8080
```

1. **No API key -> `401`:**
   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:8080/jellyfin/mcp \
     -H 'Content-Type: application/json' \
     -H 'Accept: application/json, text/event-stream' \
     -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"verify","version":"1.0"}}}'
   ```

2. **Valid key -> `tools/list` shows only the 10 allowlisted tools (`jellyfin_libraries` absent):**
   ```bash
   AGENT_KEY=$(kubectl -n agents-test get secret agentgateway-api-keys -o jsonpath='{.data.jellyfin-reader}' | base64 -d | jq -r .key)
   SID=$(curl -sS -D /tmp/agw-h -X POST http://127.0.0.1:8080/jellyfin/mcp \
     -H "Authorization: Bearer $AGENT_KEY" \
     -H 'Content-Type: application/json' \
     -H 'Accept: application/json, text/event-stream' \
     -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"verify","version":"1.0"}}}' >/dev/null && grep -i '^mcp-session-id:' /tmp/agw-h | awk '{print $2}' | tr -d '\r')

   curl -sS -X POST http://127.0.0.1:8080/jellyfin/mcp \
     -H "Authorization: Bearer $AGENT_KEY" \
     -H "Mcp-Session-Id: $SID" \
     -H 'Content-Type: application/json' \
     -H 'Accept: application/json, text/event-stream' \
     -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
   ```

3. **Calling an unlisted tool (`jellyfin_libraries`) is denied:**
   ```bash
   curl -sS -X POST http://127.0.0.1:8080/jellyfin/mcp \
     -H "Authorization: Bearer $AGENT_KEY" \
     -H "Mcp-Session-Id: $SID" \
     -H 'Content-Type: application/json' \
     -H 'Accept: application/json, text/event-stream' \
     -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"jellyfin_libraries","arguments":{}}}'
   ```

4. **Network policy test (`jellyfin-mcp` unreachable directly from another pod):**
   ```bash
   kubectl -n agents-test run nettest --rm -i --restart=Never \
     --image=busybox:1.37 --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":65534,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"nettest","image":"busybox:1.37","command":["sh","-c","wget -q -T3 -O- http://jellyfin-mcp.jellyfin.svc.cluster.local:8080/health || echo BLOCKED"],"securityContext":{"allowPrivilegeEscalation":false,"readOnlyRootFilesystem":true,"capabilities":{"drop":["ALL"]}}}]}}'
   ```

5. **End-to-end LangGraph agent:** see [`../smoke-test/README.md`](../smoke-test/README.md).
