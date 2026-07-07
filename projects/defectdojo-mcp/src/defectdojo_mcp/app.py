from __future__ import annotations

from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI, Query

from defectdojo_mcp.client.defectdojo import DefectDojoHttpClient
from defectdojo_mcp.config import Settings, get_settings
from defectdojo_mcp.mcp.context import clear_runtime, set_runtime
from defectdojo_mcp.mcp.server import mcp


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    client = DefectDojoHttpClient(settings)
    set_runtime(settings=settings, client=client)

    mcp_http = mcp.http_app(
        path="/mcp",
        transport="streamable-http",
        stateless_http=True,
        json_response=True,
        host_origin_protection=False,
    )

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        async with mcp_http.lifespan(app):
            yield
        await client.close()
        clear_runtime()

    app = FastAPI(
        title="DefectDojo MCP",
        version="0.1.0",
        lifespan=lifespan,
        redirect_slashes=False,
    )

    @app.get("/health")
    async def health(probe_defectdojo: bool = Query(default=False)) -> dict[str, object]:
        payload: dict[str, object] = {
            "ok": True,
            "defectdojo_base_url": settings.defectdojo_base_url_str,
            "readonly": settings.defectdojo_readonly,
        }
        if probe_defectdojo:
            try:
                await client.request("GET", "/api/v2/users/", params={"limit": 1})
                payload["defectdojo_reachable"] = True
            except Exception as exc:
                payload["ok"] = False
                payload["defectdojo_reachable"] = False
                payload["defectdojo_error"] = str(exc)
        return payload

    app.mount("/", mcp_http)
    return app
