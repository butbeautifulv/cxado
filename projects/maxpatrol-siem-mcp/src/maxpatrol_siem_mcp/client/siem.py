from __future__ import annotations

import json
from typing import Any

import httpx

from maxpatrol_siem_mcp.client.auth import TokenManager
from maxpatrol_siem_mcp.client.readonly import assert_readonly_allowed
from maxpatrol_siem_mcp.config import Settings


class SiemHttpClient:
    """Async HTTP client for MaxPatrol SIEM REST API with Bearer auth."""

    def __init__(self, settings: Settings, token_manager: TokenManager | None = None) -> None:
        self._settings = settings
        self._token_manager = token_manager or TokenManager(settings)
        self._client: httpx.AsyncClient | None = None

    def _http_client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(
                verify=self._settings.siem_verify_ssl,
                timeout=httpx.Timeout(60.0),
            )
        return self._client

    @property
    def token_manager(self) -> TokenManager:
        return self._token_manager

    @property
    def base_url(self) -> str:
        return self._settings.siem_base_url_str

    async def request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | list[Any] | None = None,
        form_body: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
        auth: bool = True,
        base_url: str | None = None,
    ) -> dict[str, Any]:
        assert_readonly_allowed(
            method,
            path,
            readonly=self._settings.siem_readonly,
        )
        url = self._build_url(path, base_url=base_url)
        req_headers = dict(headers or {})
        if auth:
            token = await self._token_manager.get_access_token()
            req_headers["Authorization"] = f"Bearer {token}"

        client = self._http_client()
        response = await client.request(
            method.upper(),
            url,
            params=params,
            json=json_body,
            data=form_body,
            headers=req_headers,
        )

        content_type = response.headers.get("content-type", "")
        if "application/json" in content_type:
            body: Any = response.json() if response.content else {}
        else:
            body = response.text

        if response.is_error:
            raise httpx.HTTPStatusError(
                f"SIEM API error {response.status_code}: {body}",
                request=response.request,
                response=response,
            )

        return {
            "status_code": response.status_code,
            "headers": dict(response.headers),
            "body": body,
        }

    async def request_json_string(
        self,
        method: str,
        path: str,
        **kwargs: Any,
    ) -> str:
        result = await self.request(method, path, **kwargs)
        return json.dumps(result, ensure_ascii=False, indent=2)

    @property
    def mc_base_url(self) -> str:
        return self._settings.siem_mc_base_url

    def _build_url(self, path: str, *, base_url: str | None = None) -> str:
        if path.startswith("http://") or path.startswith("https://"):
            return path
        normalized = path if path.startswith("/") else f"/{path}"
        root = base_url or self.base_url
        return f"{root.rstrip('/')}{normalized}"
