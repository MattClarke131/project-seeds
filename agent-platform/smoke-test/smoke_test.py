"""End-to-end LangGraph smoke test for agentgateway M1 (Jellyfin MCP).

The gateway API key stays in the MCP client's Authorization header and is never
placed in LangGraph state or model prompts.
"""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_mcp_adapters.tools import load_mcp_tools
from langgraph.graph import START, MessagesState, StateGraph
from langgraph.prebuilt import ToolNode, tools_condition

SYSTEM_PROMPT = (
    "You are a concise homelab Jellyfin assistant. Use the available Jellyfin MCP "
    "tools to answer the user's question accurately, then reply briefly."
)


def build_model(provider: str):
    if provider == "claude":
        from langchain_anthropic import ChatAnthropic

        api_key = os.environ.get("ANTHROPIC_API_KEY")
        model = os.environ.get("ANTHROPIC_MODEL")
        if not api_key or not model:
            raise SystemExit(
                "Missing ANTHROPIC_API_KEY or ANTHROPIC_MODEL in environment / .env"
            )
        return ChatAnthropic(model=model, api_key=api_key, temperature=0)

    if provider == "gemini":
        from langchain_google_genai import ChatGoogleGenerativeAI

        api_key = os.environ.get("GOOGLE_API_KEY")
        model = os.environ.get("GEMINI_MODEL")
        if not api_key or not model:
            raise SystemExit(
                "Missing GOOGLE_API_KEY or GEMINI_MODEL in environment / .env"
            )
        return ChatGoogleGenerativeAI(model=model, google_api_key=api_key, temperature=0)

    raise SystemExit(f"Unsupported provider: {provider}")


def build_graph(model, tools):
    bound_model = model.bind_tools(tools)

    async def call_model(state: MessagesState):
        response = await bound_model.ainvoke(state["messages"])
        return {"messages": [response]}

    builder = StateGraph(MessagesState)
    builder.add_node("agent", call_model)
    builder.add_node("tools", ToolNode(tools))
    builder.add_edge(START, "agent")
    builder.add_conditional_edges("agent", tools_condition)
    builder.add_edge("tools", "agent")
    return builder.compile()


async def run_smoke_test(args: argparse.Namespace) -> int:
    gateway_url = args.gateway_url or os.environ.get("GATEWAY_URL")
    gateway_api_key = os.environ.get("GATEWAY_API_KEY")

    if not gateway_url:
        raise SystemExit("Missing GATEWAY_URL in environment / .env (or pass --gateway-url)")
    if not gateway_api_key:
        raise SystemExit("Missing GATEWAY_API_KEY in environment / .env")

    # Token stays inside the MCP client transport headers, never in graph state.
    client = MultiServerMCPClient(
        {
            "jellyfin": {
                "transport": "streamable_http",
                "url": gateway_url,
                "headers": {
                    "Authorization": f"Bearer {gateway_api_key}",
                },
            }
        }
    )

    async with client.session("jellyfin") as session:
        tools = await load_mcp_tools(session)
        tool_names = sorted(t.name for t in tools)
        print(f"Discovered {len(tool_names)} tools via {gateway_url}:")
        for name in tool_names:
            print(f"  - {name}")

        if "jellyfin_libraries" in tool_names:
            print(
                "FAIL: jellyfin_libraries should be filtered out by the gateway",
                file=sys.stderr,
            )
            return 1

        if args.list_tools_only:
            return 0

        model = build_model(args.provider)
        graph = build_graph(model, tools)

        # Pass non-secret run metadata in config; keep secrets out of state.
        result = await graph.ainvoke(
            {
                "messages": [
                    SystemMessage(content=SYSTEM_PROMPT),
                    HumanMessage(content=args.prompt),
                ]
            },
            config={
                "recursion_limit": 10,
                "configurable": {
                    "provider": args.provider,
                    "gateway_url": gateway_url,
                },
            },
        )

    called_tools = []
    for msg in result["messages"]:
        for tc in getattr(msg, "tool_calls", None) or []:
            called_tools.append(tc["name"])

    print(f"\nProvider: {args.provider}")
    print(f"Tools called: {called_tools or ['(none)']}")
    final_msg = result["messages"][-1]
    print(f"\nResponse:\n{final_msg.content}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a LangGraph smoke test through agentgateway to jellyfin-mcp."
    )
    parser.add_argument(
        "--provider",
        choices=("claude", "gemini"),
        default="claude",
        help="LLM provider to use (configured via .env).",
    )
    parser.add_argument(
        "--env-file",
        type=Path,
        default=Path(__file__).resolve().parent / ".env",
        help="Path to the .env file containing gateway and provider credentials.",
    )
    parser.add_argument(
        "--gateway-url",
        default=None,
        help="Override GATEWAY_URL from .env.",
    )
    parser.add_argument(
        "--prompt",
        default="Use Jellyfin to check what media is available or recently added and summarize briefly.",
        help="Prompt to send to the LangGraph agent.",
    )
    parser.add_argument(
        "--list-tools-only",
        action="store_true",
        help="Connect through the gateway and list allowed tools without calling an LLM.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.env_file.exists():
        load_dotenv(args.env_file, override=False)
    else:
        load_dotenv(override=False)
    return asyncio.run(run_smoke_test(args))


if __name__ == "__main__":
    raise SystemExit(main())
