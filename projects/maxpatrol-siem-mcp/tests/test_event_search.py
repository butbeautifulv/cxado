import json

import httpx
import pytest
import respx

from maxpatrol_siem_mcp.client.auth import TokenManager
from maxpatrol_siem_mcp.client.siem import SiemHttpClient
from maxpatrol_siem_mcp.mcp.context import set_siem_client
from maxpatrol_siem_mcp.mcp.tools import events as events_tools


@pytest.fixture
def mock_token(settings):
    respx.post(f"{settings.token_url}").mock(
        return_value=httpx.Response(
            200,
            json={"access_token": "tok", "expires_in": 3600, "token_type": "Bearer"},
        )
    )


@pytest.mark.asyncio
@respx.mock
async def test_get_event_by_uuid_builds_where(settings, mock_token) -> None:
    route = respx.post(f"{settings.siem_base_url_str}/api/events/v2/events").mock(
        return_value=httpx.Response(200, json={"events": [], "totalCount": 0})
    )
    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    await events_tools.get_event_by_uuid("uuid-123")
    body = json.loads(route.calls.last.request.content)
    assert body["filter"]["where"] == 'uuid = "uuid-123"'
    assert body["filter"]["groupBy"] == []
    assert body["filter"]["orderBy"][0]["sortOrder"] == "descending"


@pytest.mark.asyncio
@respx.mock
async def test_search_events_passes_where(settings, mock_token) -> None:
    route = respx.post(f"{settings.siem_base_url_str}/api/events/v2/events").mock(
        return_value=httpx.Response(200, json={"events": []})
    )
    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    await events_tools.search_events('src.ip = "10.0.0.1"', limit=5)
    body = json.loads(route.calls.last.request.content)
    assert body["filter"]["where"] == 'src.ip = "10.0.0.1"'
    assert body["filter"]["groupBy"] == []
    assert route.calls.last.request.url.params["limit"] == "5"
