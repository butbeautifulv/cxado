from datetime import UTC, datetime

import pytest

from tenable_mcp.inventory.models import AssetRecord, FindingRecord
from tenable_mcp.inventory.repository import InventoryRepository


@pytest.mark.asyncio
async def test_get_asset_findings(settings) -> None:
    repo = InventoryRepository(settings.nessus_db_path)
    await repo.upsert_assets(
        [
            AssetRecord(
                ip="10.0.0.5",
                hostname="srv1",
                critical_count=1,
            )
        ]
    )
    await repo.upsert_findings(
        [
            FindingRecord(
                asset_ip="10.0.0.5",
                plugin_id=117886,
                plugin_name="OS Security Patch",
                severity=3,
                cvss=7.5,
            ),
            FindingRecord(
                asset_ip="10.0.0.5",
                plugin_id=19506,
                plugin_name="Scan Info",
                severity=0,
            ),
        ]
    )

    rows = await repo.get_findings_by_ip("10.0.0.5", min_severity=3)
    assert len(rows) == 1
    assert rows[0]["plugin_id"] == 117886
