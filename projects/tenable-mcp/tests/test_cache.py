import httpx
import pytest
import respx

from tenable_mcp.cache.store import CacheStore
from tenable_mcp.client.auth import SessionManager
from tenable_mcp.client.nessus import NessusHttpClient
from tenable_mcp.inventory.repository import InventoryRepository
from tenable_mcp.mcp.context import set_runtime
from tenable_mcp.mcp.tools import scans as scans_tools


@pytest.mark.asyncio
@respx.mock
async def test_list_scans_uses_cache(settings) -> None:
    base = settings.nessus_base_url_str
    respx.post(f"{base}/session").mock(return_value=httpx.Response(200, json={"token": "t"}))
    route = respx.get(f"{base}/scans").mock(
        return_value=httpx.Response(200, json={"scans": [{"id": 1, "name": "test"}]}),
    )

    client = NessusHttpClient(settings, SessionManager(settings))
    cache = CacheStore(settings.nessus_db_path)
    inventory = InventoryRepository(settings.nessus_db_path)
    set_runtime(settings=settings, client=client, inventory=inventory, cache=cache)

    await scans_tools.list_scans()
    second = await scans_tools.list_scans()

    assert route.call_count == 1
    assert "_from_cache" in second
