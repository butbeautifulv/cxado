from __future__ import annotations

import json

from tenable_mcp.mcp.context import get_inventory


async def lookup_asset_by_ip(ip: str) -> str:
    repo = get_inventory()
    rows = await repo.lookup_by_ip(ip)
    return json.dumps(rows, ensure_ascii=False, indent=2, default=str)


async def lookup_asset_by_hostname(hostname: str) -> str:
    repo = get_inventory()
    rows = await repo.lookup_by_hostname(hostname)
    return json.dumps(rows, ensure_ascii=False, indent=2, default=str)


async def search_inventory(
    ip_contains: str | None = None,
    os_contains: str | None = None,
    min_critical: int | None = None,
    min_high: int | None = None,
    limit: int = 50,
) -> str:
    repo = get_inventory()
    rows = await repo.search_inventory(
        ip_contains=ip_contains,
        os_contains=os_contains,
        min_critical=min_critical,
        min_high=min_high,
        limit=limit,
    )
    return json.dumps(rows, ensure_ascii=False, indent=2, default=str)


async def get_asset_vuln_summary(ip: str) -> str:
    repo = get_inventory()
    summary = await repo.get_vuln_summary(ip)
    if summary is None:
        return json.dumps({"error": f"No asset found for ip={ip!r}"}, ensure_ascii=False, indent=2)
    return json.dumps(summary, ensure_ascii=False, indent=2, default=str)


async def get_asset_findings(
    ip: str,
    min_severity: int | None = None,
    limit: int = 100,
) -> str:
    repo = get_inventory()
    rows = await repo.get_findings_by_ip(ip, min_severity=min_severity, limit=limit)
    return json.dumps(rows, ensure_ascii=False, indent=2, default=str)


async def list_high_risk_assets(limit: int = 50) -> str:
    repo = get_inventory()
    rows = await repo.search_inventory(min_critical=1, limit=limit)
    if rows:
        return json.dumps(rows, ensure_ascii=False, indent=2, default=str)
    rows = await repo.search_inventory(min_high=1, limit=limit)
    return json.dumps(rows, ensure_ascii=False, indent=2, default=str)
