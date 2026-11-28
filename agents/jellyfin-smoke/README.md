# jellyfin-smoke

A one-question LangGraph agent that checks agentgateway end to end: it lists the tools its key allows, asks Claude a library question, and prints each tool call and the answer. The gateway key sits in the MCP client's headers, so the model never sees it.

## Run it
```bash
kubectl -n agentgateway-system port-forward svc/mcp 8080:8080
```

In another terminal:

```bash
cd agents/jellyfin-smoke
export AGENTGATEWAY_KEY=...    # the jellyfin-smoke key (see infrastructure/kubernetes/agentgateway/README.md)
export ANTHROPIC_API_KEY=...
uv run main.py "What Dune movies are in the library?"
```

Expected:
- `tools:` lists ten `jellyfin_*` tools, without `jellyfin_libraries`.
- At least one `tool call:` line, then an answer drawn from the library.

Optional settings: `GATEWAY_URL` (default `http://127.0.0.1:8080/jellyfin/mcp`) and `MODEL` (default `claude-haiku-5-5`).
