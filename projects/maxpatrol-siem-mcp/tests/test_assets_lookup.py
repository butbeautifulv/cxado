import json

import httpx
import pytest
import respx

from maxpatrol_siem_mcp.client.auth import TokenManager
from maxpatrol_siem_mcp.client.siem import SiemHttpClient
from maxpatrol_siem_mcp.mcp.context import set_siem_client
from maxpatrol_siem_mcp.mcp.tools import assets as assets_tools


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
async def test_lookup_assets_by_pdql_chain(settings, mock_token) -> None:
    respx.post(
        f"{settings.siem_base_url_str}/api/assets_temporal_readmodel/v1/assets_grid"
    ).mock(return_value=httpx.Response(200, json={"token": "pdql-tok-1"}))
    export_route = respx.get(
        f"{settings.siem_base_url_str}/api/assets_temporal_readmodel/v1/assets_grid/export"
    ).mock(return_value=httpx.Response(200, text="host,ip\nsrv1,10.0.0.1"))

    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    raw = await assets_tools.lookup_assets_by_ip("10.0.0.1")
    payload = json.loads(raw)
    assert payload["token"] == "pdql-tok-1"
    assert export_route.called
    assert export_route.calls.last.request.url.params["pdqlToken"] == "pdql-tok-1"


@pytest.mark.asyncio
@respx.mock
async def test_audit_uses_mc_base_url(settings, mock_token) -> None:
    from maxpatrol_siem_mcp.mcp.tools import audit as audit_tools

    route = respx.get(f"{settings.siem_mc_base_url}/ptms/api/ual/v2/action_categories").mock(
        return_value=httpx.Response(200, json={"domains": []})
    )
    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    await audit_tools.list_user_action_categories()
    assert route.called
