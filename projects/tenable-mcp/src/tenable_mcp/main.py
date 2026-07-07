from __future__ import annotations

import argparse
import sys

import uvicorn

from tenable_mcp.app import create_app
from tenable_mcp.cache.store import CacheStore
from tenable_mcp.client.auth import SessionManager
from tenable_mcp.client.nessus import NessusHttpClient
from tenable_mcp.config import get_settings
from tenable_mcp.inventory.repository import InventoryRepository
from tenable_mcp.mcp.context import set_runtime
from tenable_mcp.mcp.server import mcp


def _run_stdio() -> None:
    settings = get_settings()
    client = NessusHttpClient(settings, SessionManager(settings))
    inventory = InventoryRepository(settings.nessus_db_path)
    cache = CacheStore(settings.nessus_db_path)
    set_runtime(settings=settings, client=client, inventory=inventory, cache=cache)
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
    parser = argparse.ArgumentParser(description="Tenable Nessus MCP server")
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
