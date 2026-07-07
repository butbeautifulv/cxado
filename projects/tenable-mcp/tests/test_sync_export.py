import httpx
import pytest
import respx

from tenable_mcp.cache.store import CacheStore
from tenable_mcp.client.auth import SessionManager
from tenable_mcp.client.nessus import NessusHttpClient
from tenable_mcp.inventory.repository import InventoryRepository
from tenable_mcp.mcp.context import set_runtime
from tenable_mcp.mcp.tools import sync as sync_tools

NESSUS_XML = b"""<?xml version="1.0" ?>
<NessusClientData>
  <Report name="test">
    <ReportHost name="10.0.0.5">
      <HostProperties>
        <tag name="host-ip">10.0.0.5</tag>
      </HostProperties>
      <ReportItem pluginID="117886" pluginName="Patch" severity="3" port="22" protocol="tcp" cvss3_base_score="7.5"/>
    </ReportHost>
  </Report>
</NessusClientData>
"""


@pytest.mark.asyncio
@respx.mock
async def test_sync_scan_inventory_full_flow(settings) -> None:
    base = settings.nessus_base_url_str
    respx.post(f"{base}/session").mock(return_value=httpx.Response(200, json={"token": "t"}))
    respx.get(f"{base}/scans/7/history").mock(
        return_value=httpx.Response(200, json={"history": [{"history_id": 99}]}),
    )
    respx.get(f"{base}/scans/7").mock(
        return_value=httpx.Response(
            200,
            json={
                "info": {"status": "completed", "scan_end": 1700000000},
                "hosts": [{"hostname": "10.0.0.5", "critical": 0, "high": 1}],
            },
        ),
    )
    export_route = respx.post(f"{base}/scans/7/export").mock(
        return_value=httpx.Response(200, json={"file": 42}),
    )
    respx.get(f"{base}/scans/7/export/42/status").mock(
        return_value=httpx.Response(200, json={"status": "ready"}),
    )
    respx.get(f"{base}/scans/7/export/42/download").mock(
        return_value=httpx.Response(200, content=NESSUS_XML),
    )

    client = NessusHttpClient(settings, SessionManager(settings))
    inventory = InventoryRepository(settings.nessus_db_path)
    cache = CacheStore(settings.nessus_db_path)
    set_runtime(settings=settings, client=client, inventory=inventory, cache=cache)

    result = await sync_tools.sync_scan_inventory(7)
    assert export_route.call_count == 1
    assert '"from_cache": false' in result.lower() or '"from_cache":false' in result.lower()

    assets = await inventory.lookup_by_ip("10.0.0.5")
    assert len(assets) == 1


@pytest.mark.asyncio
@respx.mock
async def test_sync_scan_inventory_skips_export_when_cached(settings) -> None:
    base = settings.nessus_base_url_str
    respx.post(f"{base}/session").mock(return_value=httpx.Response(200, json={"token": "t"}))
    respx.get(f"{base}/scans/7/history").mock(
        return_value=httpx.Response(200, json={"history": [{"history_id": 99}]}),
    )
    respx.get(f"{base}/scans/7").mock(
        return_value=httpx.Response(
            200,
            json={
                "info": {"status": "completed"},
                "hosts": [{"hostname": "10.0.0.5", "high": 1}],
            },
        ),
    )
    export_route = respx.post(f"{base}/scans/7/export").mock(
        return_value=httpx.Response(200, json={"file": 42}),
    )
    respx.get(f"{base}/scans/7/export/42/status").mock(
        return_value=httpx.Response(200, json={"status": "ready"}),
    )
    respx.get(f"{base}/scans/7/export/42/download").mock(
        return_value=httpx.Response(200, content=NESSUS_XML),
    )

    client = NessusHttpClient(settings, SessionManager(settings))
    inventory = InventoryRepository(settings.nessus_db_path)
    cache = CacheStore(settings.nessus_db_path)
    set_runtime(settings=settings, client=client, inventory=inventory, cache=cache)

    await sync_tools.sync_scan_inventory(7)
    second = await sync_tools.sync_scan_inventory(7)
    assert export_route.call_count == 1
    assert "from_cache" in second
