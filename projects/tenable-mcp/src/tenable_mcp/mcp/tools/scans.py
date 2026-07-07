from __future__ import annotations

import asyncio
import json
import time

from tenable_mcp.mcp.context import get_cache, get_nessus_client, get_settings

_TERMINAL_STATUSES = frozenset({"completed", "canceled", "aborted", "imported"})


async def list_scans(*, force_refresh: bool = False) -> str:
    settings = get_settings()
    cache = get_cache()
    cache_key = "scans:list"
    if not force_refresh:
        cached = await cache.get(cache_key)
        if cached is not None:
            return json.dumps({**cached, "_from_cache": True}, ensure_ascii=False, indent=2)

    client = get_nessus_client()
    result = await client.list_scans()
    await cache.set(cache_key, result, settings.nessus_cache_ttl_seconds)
    return client.dumps(result)


async def get_scan(scan_id: int, *, force_refresh: bool = False) -> str:
    settings = get_settings()
    cache = get_cache()
    cache_key = f"scan:{scan_id}:meta"
    if not force_refresh:
        cached = await cache.get(cache_key)
        if cached is not None:
            return json.dumps({**cached, "_from_cache": True}, ensure_ascii=False, indent=2)

    client = get_nessus_client()
    result = await client.get_scan(scan_id)
    await cache.set(cache_key, result, settings.nessus_cache_ttl_seconds)
    return client.dumps(result)


async def get_scan_status(scan_id: int, *, force_refresh: bool = False) -> str:
    text = await get_scan(scan_id, force_refresh=force_refresh)
    data = json.loads(text)
    info = data.get("info") or {}
    status = {
        "scan_id": scan_id,
        "status": info.get("status"),
        "host_count": info.get("hostcount", 0),
        "name": info.get("name"),
        "scan_end": info.get("scan_end"),
        "history_id": info.get("history_id") or info.get("object_id"),
        "_from_cache": data.get("_from_cache", False),
    }
    return json.dumps(status, ensure_ascii=False, indent=2)


async def list_scan_templates(*, force_refresh: bool = False) -> str:
    settings = get_settings()
    cache = get_cache()
    cache_key = "templates:scan"
    if not force_refresh:
        cached = await cache.get(cache_key)
        if cached is not None:
            return json.dumps({**cached, "_from_cache": True}, ensure_ascii=False, indent=2)

    client = get_nessus_client()
    result = await client.list_scan_templates()
    await cache.set(cache_key, result, max(settings.nessus_cache_ttl_seconds, 86400))
    return client.dumps(result)


async def create_scan(
    name: str,
    text_targets: str,
    template_uuid: str | None = None,
    template_name: str = "advanced",
    description: str = "",
) -> str:
    client = get_nessus_client()
    cache = get_cache()
    uuid = template_uuid
    if not uuid:
        templates = await client.list_scan_templates()
        for item in templates.get("templates", []):
            if item.get("name") == template_name:
                uuid = item.get("uuid")
                break
        if not uuid and templates.get("templates"):
            uuid = templates["templates"][0].get("uuid")
    if not uuid:
        raise ValueError(f"No scan template found for name={template_name!r}")

    result = await client.create_scan(
        name=name,
        text_targets=text_targets,
        template_uuid=uuid,
        description=description,
    )
    await cache.invalidate("scans:list")
    return client.dumps(result)


async def launch_scan(scan_id: int) -> str:
    client = get_nessus_client()
    cache = get_cache()
    result = await client.launch_scan(scan_id)
    await cache.invalidate_prefix(f"scan:{scan_id}:")
    await cache.invalidate("scans:list")
    return client.dumps(result)


async def stop_scan(scan_id: int) -> str:
    client = get_nessus_client()
    cache = get_cache()
    result = await client.stop_scan(scan_id)
    await cache.invalidate_prefix(f"scan:{scan_id}:")
    await cache.invalidate("scans:list")
    return client.dumps(result)


async def wait_for_scan(
    scan_id: int,
    *,
    poll_interval: int = 30,
    timeout: int = 7200,
) -> str:
    deadline = time.monotonic() + timeout
    last_status: dict[str, object] = {}

    while time.monotonic() < deadline:
        text = await get_scan_status(scan_id, force_refresh=True)
        last_status = json.loads(text)
        status = str(last_status.get("status") or "").lower()
        if status in _TERMINAL_STATUSES:
            return json.dumps(
                {**last_status, "finished": True, "timed_out": False},
                ensure_ascii=False,
                indent=2,
            )
        await asyncio.sleep(poll_interval)

    return json.dumps(
        {**last_status, "finished": False, "timed_out": True, "timeout_seconds": timeout},
        ensure_ascii=False,
        indent=2,
    )
