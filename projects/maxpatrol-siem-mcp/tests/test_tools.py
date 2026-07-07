import json

import httpx
import pytest
import respx
from httpx import ASGITransport, AsyncClient

from maxpatrol_siem_mcp.app import create_app
from maxpatrol_siem_mcp.client.auth import TokenManager
from maxpatrol_siem_mcp.client.readonly import ReadonlyViolationError
from maxpatrol_siem_mcp.client.siem import SiemHttpClient
from maxpatrol_siem_mcp.mcp.context import set_siem_client
from maxpatrol_siem_mcp.mcp.tools import docs as docs_tools
from maxpatrol_siem_mcp.mcp.tools import events as events_tools
from maxpatrol_siem_mcp.mcp.tools import incidents as incidents_tools


@pytest.mark.asyncio
async def test_health_endpoint(settings) -> None:
    app = create_app(settings)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/health")
    assert response.status_code == 200
    payload = response.json()
    assert payload["ok"] is True
    assert payload["siem_base_url"] == "https://siem.test.local"


@pytest.mark.asyncio
@respx.mock
async def test_list_incidents_tool(settings) -> None:
    respx.post(f"{settings.token_url}").mock(
        return_value=httpx.Response(
            200,
            json={"access_token": "tok", "expires_in": 3600, "token_type": "Bearer"},
        )
    )
    respx.post(f"{settings.siem_base_url_str}/api/v2/incidents").mock(
        return_value=httpx.Response(200, json={"incidents": [], "totalItems": 0})
    )

    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    result = await incidents_tools.list_incidents(limit=10, offset=0)
    assert "incidents" in result


@pytest.mark.asyncio
@respx.mock
async def test_list_events_sends_default_body(settings) -> None:
    respx.post(f"{settings.token_url}").mock(
        return_value=httpx.Response(
            200,
            json={"access_token": "tok", "expires_in": 3600, "token_type": "Bearer"},
        )
    )
    route = respx.post(f"{settings.siem_base_url_str}/api/events/v2/events").mock(
        return_value=httpx.Response(200, json={"events": []})
    )

    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    await events_tools.list_events(limit=10, offset=0)
    body = json.loads(route.calls.last.request.content)
    assert "timeFrom" in body
    assert body["filter"]["select"]
    assert body["filter"]["groupBy"] == []


@pytest.mark.asyncio
@respx.mock
async def test_siem_client_blocks_delete_in_readonly_mode(settings) -> None:
    client = SiemHttpClient(settings, TokenManager(settings))
    with pytest.raises(ReadonlyViolationError):
        await client.request("DELETE", "/api/v2/incidents/abc")


@pytest.mark.asyncio
async def test_search_api_docs() -> None:
    result = await docs_tools.search_api_docs("connect/token", max_results=2)
    assert "connect/token" in result.lower() or "токен" in result.lower()
