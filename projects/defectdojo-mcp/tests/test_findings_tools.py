from __future__ import annotations

import httpx
import pytest
import respx

from defectdojo_mcp.client.defectdojo import DefectDojoHttpClient
from defectdojo_mcp.config import Settings
from defectdojo_mcp.mcp.context import set_runtime
from defectdojo_mcp.mcp.tools import findings as finding_tools


@pytest.mark.asyncio
@respx.mock
async def test_list_findings(settings: Settings) -> None:
    respx.get("http://defectdojo.test.local/api/v2/findings/").mock(
        return_value=httpx.Response(
            200,
            json={"count": 1, "results": [{"id": 42, "title": "SQLi"}]},
        )
    )
    client = DefectDojoHttpClient(settings)
    set_runtime(settings=settings, client=client)
    text = await finding_tools.list_findings(severity="High", limit=10)
    assert "SQLi" in text
    assert "42" in text


@pytest.mark.asyncio
@respx.mock
async def test_update_finding(settings: Settings) -> None:
    respx.patch("http://defectdojo.test.local/api/v2/findings/7/").mock(
        return_value=httpx.Response(200, json={"id": 7, "active": False})
    )
    client = DefectDojoHttpClient(settings)
    set_runtime(settings=settings, client=client)
    text = await finding_tools.update_finding(7, {"active": False})
    assert '"active": false' in text
