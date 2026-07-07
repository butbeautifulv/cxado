import httpx
import pytest
import respx

from tenable_mcp.client.auth import SessionManager


@pytest.mark.asyncio
@respx.mock
async def test_session_login_caches_token(settings) -> None:
    route = respx.post(f"{settings.nessus_base_url_str}/session").mock(
        return_value=httpx.Response(200, json={"token": "abc123"}),
    )
    manager = SessionManager(settings)

    token1 = await manager.get_token()
    token2 = await manager.get_token()

    assert token1 == "abc123"
    assert token2 == "abc123"
    assert route.call_count == 1
    assert manager.has_cached_token
