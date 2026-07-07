from __future__ import annotations

import httpx
import pytest
import respx
from httpx import ASGITransport

from defectdojo_mcp.app import create_app
from defectdojo_mcp.config import Settings


@pytest.mark.asyncio
async def test_health_liveness(settings: Settings) -> None:
    app = create_app(settings)
    transport = ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["ok"] is True
    assert data["defectdojo_base_url"] == "http://defectdojo.test.local"


@pytest.mark.asyncio
@respx.mock
async def test_health_probe_defectdojo(settings: Settings) -> None:
    respx.get("http://defectdojo.test.local/api/v2/users/").mock(
        return_value=httpx.Response(200, json={"count": 1, "results": []})
    )
    app = create_app(settings)
    transport = ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/health", params={"probe_defectdojo": "true"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["ok"] is True
    assert data["defectdojo_reachable"] is True
