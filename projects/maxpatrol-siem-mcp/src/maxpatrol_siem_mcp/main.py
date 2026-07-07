from __future__ import annotations

import argparse
import sys

import uvicorn

from maxpatrol_siem_mcp.app import create_app
from maxpatrol_siem_mcp.client.auth import TokenManager
from maxpatrol_siem_mcp.client.siem import SiemHttpClient
from maxpatrol_siem_mcp.config import get_settings
from maxpatrol_siem_mcp.mcp.context import set_siem_client
from maxpatrol_siem_mcp.mcp.server import mcp


def _run_stdio() -> None:
    settings = get_settings()
    set_siem_client(SiemHttpClient(settings, TokenManager(settings)))
    mcp.run(transport="stdio")


def _run_serve() -> None:
    settings = get_settings()
    uvicorn.run(
        create_app,
        factory=True,
        host=settings.mcp_host,
        port=settings.mcp_port,
        reload=False,
    )


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="MaxPatrol SIEM MCP server")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("stdio", help="Run MCP over stdio (Cursor)")
    sub.add_parser("serve", help="Run FastAPI + streamable HTTP MCP on /mcp")
    args = parser.parse_args(argv)

    if args.command == "stdio":
        _run_stdio()
    elif args.command == "serve":
        _run_serve()
    else:
        parser.print_help()
        sys.exit(2)


if __name__ == "__main__":
    main()
