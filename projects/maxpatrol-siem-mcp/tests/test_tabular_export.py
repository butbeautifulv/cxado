import json

import httpx
import pytest
import respx

from maxpatrol_siem_mcp.client.auth import TokenManager
from maxpatrol_siem_mcp.client.readonly import assert_readonly_allowed
from maxpatrol_siem_mcp.client.siem import SiemHttpClient
from maxpatrol_siem_mcp.mcp.context import set_siem_client
from maxpatrol_siem_mcp.mcp.tools import tabular as tabular_tools


@pytest.fixture
def mock_token(settings):
    respx.post(f"{settings.token_url}").mock(
        return_value=httpx.Response(
            200,
            json={"access_token": "tok", "expires_in": 3600, "token_type": "Bearer"},
        )
    )


def test_readonly_allows_table_list_export() -> None:
    assert_readonly_allowed(
        "POST",
        "/api/events/v1/table_lists/MyList/export",
        readonly=True,
    )


def test_readonly_allows_user_actions_search() -> None:
    assert_readonly_allowed(
        "POST",
        "/ptms/api/ual/v2/user_actions",
        readonly=True,
    )


def test_readonly_blocks_table_list_import() -> None:
    from maxpatrol_siem_mcp.client.readonly import ReadonlyViolationError

    with pytest.raises(ReadonlyViolationError):
        assert_readonly_allowed(
            "POST",
            "/api/events/v1/table_lists/MyList/import",
            readonly=True,
        )


@pytest.mark.asyncio
@respx.mock
async def test_export_table_list(settings, mock_token) -> None:
    route = respx.post(
        f"{settings.siem_base_url_str}/api/events/v1/table_lists/bad_ips/export"
    ).mock(return_value=httpx.Response(200, text="col1,col2\nval1,val2"))
    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    result = await tabular_tools.export_table_list(
        "bad_ips",
        where='ip = "10.0.0.1"',
        select=["ip", "reason"],
    )
    payload = json.loads(result)
    assert route.called
    body = json.loads(route.calls.last.request.content)
    assert body["filter"]["where"] == 'ip = "10.0.0.1"'
    assert "col1" in payload["body"] or "val1" in str(payload)
