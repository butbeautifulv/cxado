from __future__ import annotations

import httpx
import pytest
import respx

from defectdojo_mcp.client.defectdojo import DefectDojoHttpClient
from defectdojo_mcp.config import Settings
from defectdojo_mcp.mcp.context import set_runtime
from defectdojo_mcp.mcp.tools import import_scan as import_tools


@pytest.mark.asyncio
@respx.mock
async def test_import_scan_multipart(settings: Settings, tmp_path) -> None:
    report = tmp_path / "semgrep.json"
    report.write_text('{"results": []}', encoding="utf-8")

    route = respx.post("http://defectdojo.test.local/api/v2/import-scan/").mock(
        return_value=httpx.Response(201, json={"test": 99, "engagement": 5})
    )

    client = DefectDojoHttpClient(settings)
    set_runtime(settings=settings, client=client)
    text = await import_tools.import_scan(
        scan_type="Semgrep JSON Report",
        file_path=str(report),
        product=1,
        engagement=2,
    )
    assert "99" in text
    assert route.called
    request = route.calls[0].request
    assert b"multipart/form-data" in request.headers.get("content-type", "").encode() or "multipart" in str(
        request.headers.get("content-type", "")
    )
