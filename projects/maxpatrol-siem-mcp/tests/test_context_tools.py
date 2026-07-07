import httpx
import pytest
import respx

from maxpatrol_siem_mcp.client.auth import TokenManager
from maxpatrol_siem_mcp.client.siem import SiemHttpClient
from maxpatrol_siem_mcp.mcp.context import set_siem_client
from maxpatrol_siem_mcp.mcp.tools import context as context_tools


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
async def test_list_scopes(settings, mock_token) -> None:
    route = respx.get(f"{settings.siem_base_url_str}/api/scopes/v2/scopes").mock(
        return_value=httpx.Response(200, json=[{"id": "scope-1", "name": "Default"}])
    )
    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    result = await context_tools.list_scopes()
    assert "scope-1" in result
    assert route.called


@pytest.mark.asyncio
@respx.mock
async def test_get_incident_filters_hierarchy(settings, mock_token) -> None:
    route = respx.get(
        f"{settings.siem_base_url_str}/api/v1/incidents/filters_hierarchy"
    ).mock(return_value=httpx.Response(200, json={"filters": []}))
    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    result = await context_tools.get_incident_filters_hierarchy()
    assert "filters" in result
    assert route.called
