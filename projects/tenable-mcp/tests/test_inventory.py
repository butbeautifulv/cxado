from datetime import UTC, datetime

import pytest

from tenable_mcp.inventory.models import AssetRecord, FindingRecord
from tenable_mcp.inventory.nessus_parser import parse_nessus_xml, parse_scan_json_hosts
from tenable_mcp.inventory.repository import InventoryRepository

NESSUS_XML = b"""<?xml version="1.0" ?>
<NessusClientData>
  <Report name="test">
    <ReportHost name="10.0.0.5">
      <HostProperties>
        <tag name="host-ip">10.0.0.5</tag>
        <tag name="operating-system">Ubuntu 22.04</tag>
      </HostProperties>
      <ReportItem pluginID="19506" pluginName="Nessus Scan Information" severity="0" port="0" protocol="tcp"/>
      <ReportItem pluginID="117886" pluginName="OS Security Patch" severity="3" port="22" protocol="tcp" cvss3_base_score="7.5"/>
    </ReportHost>
  </Report>
</NessusClientData>
"""


def test_parse_scan_json_hosts() -> None:
    data = {
        "info": {"scan_end": 1700000000},
        "hosts": [
            {
                "hostname": "host1",
                "host_id": 10,
                "critical": 1,
                "high": 2,
                "medium": 0,
                "low": 0,
                "info": 1,
            }
        ],
    }
    assets, findings = parse_scan_json_hosts(data, scan_id=5, history_id=99)
    assert len(assets) == 1
    assert assets[0].ip == "host1"
    assert assets[0].critical_count == 1
    assert findings == []


def test_parse_nessus_xml() -> None:
    assets, findings = parse_nessus_xml(NESSUS_XML, scan_id=1, history_id=2)
    assert len(assets) == 1
    assert assets[0].ip == "10.0.0.5"
    assert assets[0].high_count == 1
    assert len(findings) == 2


@pytest.mark.asyncio
async def test_inventory_upsert_and_lookup(settings) -> None:
    repo = InventoryRepository(settings.nessus_db_path)
    asset = AssetRecord(
        hostname="srv1",
        ip="10.0.0.5",
        last_scan_id=1,
        last_history_id=2,
        last_scan_at=datetime.now(tz=UTC),
        critical_count=1,
        high_count=2,
    )
    await repo.upsert_assets([asset])
    await repo.upsert_findings(
        [
            FindingRecord(
                asset_ip="10.0.0.5",
                plugin_id=117886,
                plugin_name="OS Security Patch",
                severity=3,
                cvss=7.5,
            )
        ]
    )

    rows = await repo.lookup_by_ip("10.0.0.5")
    assert len(rows) == 1
    assert rows[0]["critical_count"] == 1

    summary = await repo.get_vuln_summary("10.0.0.5")
    assert summary is not None
    assert summary["high_count"] == 2
