# LangGraph Smoke Test (M1)

Minimal LangGraph agent that connects to `jellyfin-mcp` through `agentgateway` over Streamable HTTP. The gateway API key lives in the MCP client's `Authorization` header (never in LangGraph state or prompts).

## Setup

1. Copy `.env.example` to `.env` (gitignored) and fill in your keys and model names:
   ```bash
   cd agent-platform/smoke-test
   cp .env.example .env
   ```
   Supported variables:
   - `GATEWAY_URL`: e.g. `http://127.0.0.1:8080/jellyfin/mcp`
   - `GATEWAY_API_KEY`: static key from `agentgateway-api-keys`
   - `ANTHROPIC_API_KEY` and `ANTHROPIC_MODEL`: used with `--provider claude`
   - `GOOGLE_API_KEY` and `GEMINI_MODEL`: used with `--provider gemini`

2. Forward the internal gateway Service:
   ```bash
   kubectl -n agents-test port-forward svc/mcp-gateway 8080:8080
   ```

## Run

Verify MCP tool discovery through the gateway (no LLM call):
```bash
uv run python smoke_test.py --list-tools-only
```

Run the full LangGraph agent with Claude or Gemini:
```bash
uv run python smoke_test.py --provider claude
uv run python smoke_test.py --provider gemini
```
