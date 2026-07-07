from __future__ import annotations

from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI, Query

from tenable_mcp.cache.store import CacheStore
from tenable_mcp.client.auth import SessionManager
from tenable_mcp.client.nessus import NessusHttpClient
from tenable_mcp.config import Settings, get_settings
from tenable_mcp.inventory.repository import InventoryRepository
from tenable_mcp.mcp.context import clear_runtime, set_runtime
from tenable_mcp.mcp.server import mcp


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    session_manager = SessionManager(settings)
    nessus_client = NessusHttpClient(settings, session_manager)
    inventory = InventoryRepository(settings.nessus_db_path)
    cache = CacheStore(settings.nessus_db_path)

    set_runtime(
        settings=settings,
        client=nessus_client,
        inventory=inventory,
        cache=cache,
    )

    mcp_http = mcp.http_app(
        path="/mcp",
        transport="streamable-http",
        stateless_http=True,
        json_response=True,
        host_origin_protection=False,
    )

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        await inventory.ensure_initialized()
        await cache.ensure_initialized()
        async with mcp_http.lifespan(app):
            yield
        await nessus_client.close()
        clear_runtime()

    app = FastAPI(
        title="Tenable Nessus MCP",
        version="0.1.0",
        lifespan=lifespan,
        redirect_slashes=False,
    )

    @app.get("/health")
    async def health(probe_nessus: bool = Query(default=False)) -> dict[str, object]:
        payload: dict[str, object] = {
            "ok": True,
            "nessus_base_url": settings.nessus_base_url_str,
            "session_cached": session_manager.has_cached_token,
            "readonly": settings.nessus_readonly,
            "db_path": settings.nessus_db_path,
        }
        if probe_nessus:
            try:
                await nessus_client.list_scans()
                payload["nessus_reachable"] = True
            except Exception as exc:
                payload["ok"] = False
                payload["nessus_reachable"] = False
                payload["nessus_error"] = str(exc)
        return payload

    app.mount("/", mcp_http)
    return app
