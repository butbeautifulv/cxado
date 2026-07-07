from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any

import httpx

from maxpatrol_siem_mcp.config import Settings


@dataclass
class TokenBundle:
    access_token: str
    expires_at: float
    refresh_token: str | None = None
    token_type: str = "Bearer"


class TokenManager:
    """OAuth token acquisition and in-memory cache for MaxPatrol SIEM."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._token: TokenBundle | None = None

    @property
    def has_cached_token(self) -> bool:
        return self._token is not None and time.time() < self._token.expires_at

    async def get_access_token(self, *, force_refresh: bool = False) -> str:
        if not force_refresh and self._token and time.time() < self._token.expires_at:
            return self._token.access_token
        if (
            not force_refresh
            and self._token
            and self._token.refresh_token
            and "offline_access" in self._settings.siem_scope
        ):
            try:
                return await self._refresh_token()
            except httpx.HTTPError:
                pass
        return await self._password_grant()

    async def fetch_token_response(self, *, force_refresh: bool = False) -> dict[str, Any]:
        token = await self.get_access_token(force_refresh=force_refresh)
        if not self._token:
            raise RuntimeError("token bundle missing after acquisition")
        return {
            "access_token": token,
            "expires_at": self._token.expires_at,
            "refresh_token": self._token.refresh_token,
            "token_type": self._token.token_type,
        }

    async def _password_grant(self) -> str:
        data = {
            "client_id": self._settings.siem_client_id,
            "client_secret": self._settings.siem_client_secret,
            "grant_type": "password",
            "username": self._settings.siem_username,
            "password": self._settings.siem_password,
            "response_type": "token",
            "scope": self._settings.siem_scope,
        }
        return await self._request_token(data)

    async def _refresh_token(self) -> str:
        if not self._token or not self._token.refresh_token:
            raise RuntimeError("no refresh token available")
        data = {
            "client_id": self._settings.siem_client_id,
            "client_secret": self._settings.siem_client_secret,
            "grant_type": "refresh_token",
            "refresh_token": self._token.refresh_token,
            "response_type": "token",
            "scope": self._settings.siem_scope,
        }
        return await self._request_token(data)

    async def _request_token(self, data: dict[str, str]) -> str:
        async with httpx.AsyncClient(verify=self._settings.siem_verify_ssl) as client:
            response = await client.post(
                self._settings.token_url,
                data=data,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
            response.raise_for_status()
            payload = response.json()
        expires_in = int(payload.get("expires_in", 3600))
        self._token = TokenBundle(
            access_token=payload["access_token"],
            expires_at=time.time() + max(expires_in - 30, 60),
            refresh_token=payload.get("refresh_token"),
            token_type=payload.get("token_type", "Bearer"),
        )
        return self._token.access_token
