import httpx
import pytest
import respx

from maxpatrol_siem_mcp.client.auth import TokenBundle, TokenManager


@pytest.mark.asyncio
@respx.mock
async def test_password_grant_caches_token(settings) -> None:
    route = respx.post(f"{settings.token_url}").mock(
        return_value=httpx.Response(
            200,
            json={
                "access_token": "abc123",
                "expires_in": 3600,
                "token_type": "Bearer",
                "refresh_token": "refresh-1",
            },
        )
    )
    manager = TokenManager(settings)

    token1 = await manager.get_access_token()
    token2 = await manager.get_access_token()

    assert token1 == "abc123"
    assert token2 == "abc123"
    assert route.call_count == 1
    assert manager.has_cached_token


@pytest.mark.asyncio
@respx.mock
async def test_refresh_token_used_when_expired(settings) -> None:
    token_route = respx.post(f"{settings.token_url}").mock(
        return_value=httpx.Response(
            200,
            json={
                "access_token": "new",
                "expires_in": 3600,
                "refresh_token": "refresh-2",
            },
        )
    )
    manager = TokenManager(settings)
    manager._token = TokenBundle(
        access_token="old",
        expires_at=0,
        refresh_token="refresh-1",
    )

    token = await manager.get_access_token()
    assert token == "new"
    assert token_route.call_count >= 1
