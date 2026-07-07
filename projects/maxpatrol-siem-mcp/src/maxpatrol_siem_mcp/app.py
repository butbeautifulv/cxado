from __future__ import annotations

from fastapi import FastAPI

from maxpatrol_siem_mcp.client.auth import TokenManager
from maxpatrol_siem_mcp.client.siem import SiemHttpClient
from maxpatrol_siem_mcp.config import Settings, get_settings
from maxpatrol_siem_mcp.mcp.context import set_siem_client
from maxpatrol_siem_mcp.mcp.server import mcp


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    token_manager = TokenManager(settings)
    siem_client = SiemHttpClient(settings, token_manager)
    set_siem_client(siem_client)

    mcp_http = mcp.http_app(
        path="/mcp",
        transport="streamable-http",
        stateless_http=True,
        json_response=True,
        host_origin_protection=False,
    )

    app = FastAPI(
        title="MaxPatrol SIEM MCP",
        version="0.1.0",
        lifespan=mcp_http.lifespan,
        redirect_slashes=False,
    )

    @app.get("/health")
    async def health() -> dict[str, object]:
        return {
            "ok": True,
            "siem_base_url": settings.siem_base_url_str,
            "token_cached": token_manager.has_cached_token,
        }

    app.mount("/", mcp_http)
    return app
