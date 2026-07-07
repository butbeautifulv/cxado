from __future__ import annotations

import pytest

from defectdojo_mcp.client.defectdojo import DefectDojoHttpClient
from defectdojo_mcp.client.readonly import ReadonlyViolationError
from defectdojo_mcp.config import Settings


@pytest.mark.asyncio
async def test_readonly_blocks_patch() -> None:
    settings = Settings(
        defectdojo_base_url="http://defectdojo.test.local",
        defectdojo_api_key="token",
        defectdojo_verify_ssl=False,
        defectdojo_readonly=True,
    )
    client = DefectDojoHttpClient(settings)
    with pytest.raises(ReadonlyViolationError):
        await client.request("PATCH", "/api/v2/findings/1/", json_body={"active": False})


@pytest.mark.asyncio
async def test_readonly_allows_get() -> None:
    from defectdojo_mcp.client.readonly import assert_readonly_allowed

    assert_readonly_allowed("GET", "/api/v2/findings/", readonly=True)
