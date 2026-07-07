from __future__ import annotations

import asyncio
import json
from typing import Any

import httpx

from tenable_mcp.client.auth import SessionManager
from tenable_mcp.client.readonly import assert_readonly_allowed
from tenable_mcp.config import Settings


class NessusHttpClient:
    """Async HTTP client for local Nessus REST API."""

    def __init__(self, settings: Settings, session_manager: SessionManager | None = None) -> None:
        self._settings = settings
        self._session = session_manager or SessionManager(settings)
        self._client: httpx.AsyncClient | None = None

    def _http_client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(
                verify=self._settings.nessus_verify_ssl,
                timeout=httpx.Timeout(120.0),
            )
        return self._client

    @property
    def session_manager(self) -> SessionManager:
        return self._session

    @property
    def base_url(self) -> str:
        return self._settings.nessus_base_url_str

    async def close(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None

    async def request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | list[Any] | None = None,
        auth: bool = True,
        raw: bool = False,
    ) -> dict[str, Any] | bytes | str:
        assert_readonly_allowed(method, path, readonly=self._settings.nessus_readonly)
        url = self._build_url(path)
        headers: dict[str, str] = {"Content-Type": "application/json"}
        if auth:
            token = await self._session.get_token()
            headers["X-Cookie"] = f"token={token}"

        client = self._http_client()
        response = await client.request(
            method.upper(),
            url,
            params=params,
            json=json_body,
            headers=headers,
        )

        if response.status_code == 401 and auth:
            await self._session.invalidate()
            token = await self._session.get_token(force_refresh=True)
            headers["X-Cookie"] = f"token={token}"
            response = await client.request(
                method.upper(),
                url,
                params=params,
                json=json_body,
                headers=headers,
            )

        if raw:
            response.raise_for_status()
            return response.content

        content_type = response.headers.get("content-type", "")
        if "application/json" in content_type:
            body: Any = response.json() if response.content else {}
        else:
            body = response.text

        if response.is_error:
            raise httpx.HTTPStatusError(
                f"Nessus API error {response.status_code}: {body}",
                request=response.request,
                response=response,
            )
        return body

    def _build_url(self, path: str) -> str:
        if path.startswith("http://") or path.startswith("https://"):
            return path
        normalized = path if path.startswith("/") else f"/{path}"
        return f"{self.base_url}{normalized}"

    async def list_scans(self) -> dict[str, Any]:
        result = await self.request("GET", "/scans")
        assert isinstance(result, dict)
        return result

    async def get_scan(self, scan_id: int, *, history_id: int | None = None) -> dict[str, Any]:
        params = {"history_id": history_id} if history_id is not None else None
        result = await self.request("GET", f"/scans/{scan_id}", params=params)
        assert isinstance(result, dict)
        return result

    async def get_scan_history(self, scan_id: int) -> dict[str, Any]:
        result = await self.request("GET", f"/scans/{scan_id}/history")
        assert isinstance(result, dict)
        return result

    async def list_scan_templates(self) -> dict[str, Any]:
        result = await self.request("GET", "/editor/scan/templates")
        assert isinstance(result, dict)
        return result

    async def create_scan(
        self,
        *,
        name: str,
        text_targets: str,
        template_uuid: str,
        description: str = "",
    ) -> dict[str, Any]:
        payload = {
            "uuid": template_uuid,
            "settings": {
                "name": name,
                "text_targets": text_targets,
                "enabled": True,
                "launch": "ON_DEMAND",
                "description": description,
            },
        }
        result = await self.request("POST", "/scans", json_body=payload)
        assert isinstance(result, dict)
        return result

    async def launch_scan(self, scan_id: int) -> dict[str, Any]:
        result = await self.request("POST", f"/scans/{scan_id}/launch")
        assert isinstance(result, dict)
        return result

    async def stop_scan(self, scan_id: int) -> dict[str, Any]:
        result = await self.request("POST", f"/scans/{scan_id}/stop")
        assert isinstance(result, dict)
        return result

    async def export_scan(
        self,
        scan_id: int,
        *,
        export_format: str = "nessus",
        history_id: int | None = None,
        poll_interval: float = 2.0,
        max_attempts: int = 90,
    ) -> bytes:
        payload: dict[str, Any] = {"format": export_format}
        if history_id is not None:
            payload["history_id"] = history_id

        export_resp = await self.request(
            "POST",
            f"/scans/{scan_id}/export",
            json_body=payload,
        )
        assert isinstance(export_resp, dict)
        file_id = export_resp.get("file")
        if file_id is None:
            raise RuntimeError(f"Export request failed: {export_resp}")

        await self._wait_export_ready(scan_id, int(file_id), poll_interval, max_attempts)

        content = await self.request(
            "GET",
            f"/scans/{scan_id}/export/{file_id}/download",
            raw=True,
        )
        assert isinstance(content, bytes)
        return content

    async def _wait_export_ready(
        self,
        scan_id: int,
        file_id: int,
        poll_interval: float,
        max_attempts: int,
    ) -> None:
        for _ in range(max_attempts):
            status_resp = await self.request(
                "GET",
                f"/scans/{scan_id}/export/{file_id}/status",
            )
            assert isinstance(status_resp, dict)
            if status_resp.get("status") == "ready":
                return
            await asyncio.sleep(poll_interval)
        raise RuntimeError(f"Export {file_id} for scan {scan_id} not ready after polling")

    async def latest_history_id(self, scan_id: int) -> int | None:
        history = await self.get_scan_history(scan_id)
        entries = history.get("history") or []
        if not entries:
            scan = await self.get_scan(scan_id)
            info = scan.get("info") or {}
            raw = info.get("history_id") or info.get("object_id")
            return int(raw) if raw is not None else None
        latest = max(entries, key=lambda item: item.get("history_id", 0))
        history_id = latest.get("history_id")
        return int(history_id) if history_id is not None else None

    def dumps(self, data: Any) -> str:
        return json.dumps(data, ensure_ascii=False, indent=2)
