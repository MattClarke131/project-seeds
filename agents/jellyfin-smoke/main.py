"""Asks one library question through agentgateway and prints the tools seen and the answer.

Needs AGENTGATEWAY_KEY and ANTHROPIC_API_KEY in the environment; see README.md.
"""

import asyncio
import os
import sys

from langchain_anthropic import ChatAnthropic
from langchain_mcp_adapters.client import MultiServerMCPClient
from langgraph.prebuilt import create_react_agent

GATEWAY_URL = os.environ.get("GATEWAY_URL", "http://127.0.0.1:8080/jellyfin/mcp")
MODEL = os.environ.get("MODEL", "claude-haiku-5-5")
QUESTION = sys.argv[1] if len(sys.argv) > 1 else "Search the library for 'Dune' and list what you find."


async def main() -> None:
    # The key lives only in the client's headers, so the model never sees it.
    client = MultiServerMCPClient(
        {
            "jellyfin": {
                "transport": "streamable_http",
                "url": GATEWAY_URL,
                "headers": {"Authorization": f"Bearer {os.environ['AGENTGATEWAY_KEY']}"},
            }
        }
    )
    tools = await client.get_tools()
    print("tools:", sorted(t.name for t in tools))

    agent = create_react_agent(ChatAnthropic(model=MODEL), tools)
    result = await agent.ainvoke({"messages": [("user", QUESTION)]})
    for message in result["messages"]:
        for call in getattr(message, "tool_calls", None) or []:
            print("tool call:", call["name"], call["args"])
    print("answer:", result["messages"][-1].content)


if __name__ == "__main__":
    asyncio.run(main())
