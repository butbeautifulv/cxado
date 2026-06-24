from __future__ import annotations

import time
from dataclasses import dataclass, field

import httpx

from cxado_auth_client.cache import TTLCache


@dataclass
class AuthBrokerClient:
    base_url: str
    service_token: str
    service_id: str = "default"
    audience: str = "veil-api"
    timeout: float = 30.0
    _cache: TTLCache = field(default_factory=TTLCache, init=False, repr=False)

    def get_access_token(self, audience: str | None = None, scopes: list[str] | None = None) -> str:
        aud = (audience or self.audience).strip()
        if not aud:
            raise ValueError("audience is required")
        scope_list = scopes or []
        cache_key = (aud, tuple(scope_list))
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        url = self.base_url.rstrip("/") + "/v1/token"
        headers = {
            "Authorization": f"Bearer {self.service_token}",
            "Content-Type": "application/json",
            "X-Service-Id": self.service_id,
        }
        payload = {"audience": aud, "scopes": scope_list}
        with httpx.Client(timeout=self.timeout) as client:
            resp = client.post(url, json=payload, headers=headers)
            resp.raise_for_status()
            data = resp.json()
        token = str(data.get("access_token", "")).strip()
        if not token:
            raise RuntimeError("auth broker returned empty access_token")
        expires_in = int(data.get("expires_in", 60))
        self._cache.put(cache_key, token, max(expires_in - 30, 1))
        return token
