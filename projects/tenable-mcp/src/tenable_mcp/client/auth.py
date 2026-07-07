from __future__ import annotations

import httpx

from tenable_mcp.config import Settings


class SessionManager:
    """Nessus session token acquisition and in-memory cache."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._token: str | None = None

    @property
    def has_cached_token(self) -> bool:
        return self._token is not None

    async def get_token(self, *, force_refresh: bool = False) -> str:
        if not force_refresh and self._token:
            return self._token
        return await self._login()

    async def invalidate(self) -> None:
        self._token = None

    async def _login(self) -> str:
        url = f"{self._settings.nessus_base_url_str}/session"
        async with httpx.AsyncClient(verify=self._settings.nessus_verify_ssl) as client:
            response = await client.post(
                url,
                json={
                    "username": self._settings.nessus_username,
                    "password": self._settings.nessus_password,
                },
                headers={"Content-Type": "application/json"},
            )
            response.raise_for_status()
            payload = response.json()
        token = payload.get("token")
        if not token:
            raise RuntimeError("Nessus session response missing token")
        self._token = token
        return token
