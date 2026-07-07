from __future__ import annotations

import base64
import json
from typing import Any

import httpx
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

from defectdojo_mcp.client.readonly import assert_readonly_allowed
from defectdojo_mcp.config import Settings


class DefectDojoApiError(Exception):
    """DefectDojo REST API request failed."""

    def __init__(self, message: str, *, status_code: int | None = None, body: Any = None) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.body = body


class DefectDojoHttpClient:
    """Async HTTP client for DefectDojo API v2 with Token auth."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client: httpx.AsyncClient | None = None

    def _http_client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(
                verify=self._settings.defectdojo_verify_ssl,
                timeout=httpx.Timeout(120.0),
            )
        return self._client

    @property
    def base_url(self) -> str:
        return self._settings.defectdojo_base_url_str

    @property
    def readonly(self) -> bool:
        return self._settings.defectdojo_readonly

    def _auth_headers(self) -> dict[str, str]:
        return {"Authorization": f"Token {self._settings.defectdojo_api_key}"}

    def _build_url(self, path: str) -> str:
        if path.startswith("http://") or path.startswith("https://"):
            return path
        normalized = path if path.startswith("/") else f"/{path}"
        return f"{self.base_url.rstrip('/')}{normalized}"

    @retry(
        retry=retry_if_exception_type(httpx.HTTPStatusError),
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=0.5, min=0.5, max=4),
        reraise=True,
    )
    async def request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | list[Any] | None = None,
        data: dict[str, Any] | None = None,
        files: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        assert_readonly_allowed(method, path, readonly=self._settings.defectdojo_readonly)

        url = self._build_url(path)
        req_headers = {**self._auth_headers(), **(headers or {})}
        client = self._http_client()

        response = await client.request(
            method.upper(),
            url,
            params=params,
            json=json_body,
            data=data,
            files=files,
            headers=req_headers,
        )

        content_type = response.headers.get("content-type", "")
        if "application/json" in content_type:
            body: Any = response.json() if response.content else {}
        else:
            body = response.text

        if response.status_code == 429 or response.status_code >= 500:
            raise httpx.HTTPStatusError(
                f"DefectDojo API error {response.status_code}",
                request=response.request,
                response=response,
            )

        if response.is_error:
            raise DefectDojoApiError(
                f"DefectDojo API error {response.status_code}: {body}",
                status_code=response.status_code,
                body=body,
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

    async def close(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None

    @staticmethod
    def decode_file_payload(
        *,
        file_path: str | None = None,
        file_base64: str | None = None,
        file_name: str = "scan_report.json",
    ) -> tuple[str, bytes, str]:
        if file_path:
            path = file_path
            content = open(path, "rb").read()
            name = path.rsplit("/", 1)[-1]
            return "file", content, name
        if file_base64:
            content = base64.b64decode(file_base64)
            return "file", content, file_name
        raise ValueError("Either file_path or file_base64 is required for file upload")

    def dumps(self, data: Any) -> str:
        return json.dumps(data, ensure_ascii=False, indent=2)
