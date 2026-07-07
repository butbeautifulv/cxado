from __future__ import annotations

from typing import Any

from fastmcp import FastMCP

from tenable_mcp.mcp.tools import docs as docs_tools
from tenable_mcp.mcp.tools import inventory as inventory_tools
from tenable_mcp.mcp.tools import request as request_tools
from tenable_mcp.mcp.tools import scans as scans_tools
from tenable_mcp.mcp.tools import sync as sync_tools

mcp = FastMCP("tenable-mcp")


@mcp.tool()
async def list_scans(force_refresh: bool = False) -> str:
    """List Nessus scan configurations and their last-known status."""
    return await scans_tools.list_scans(force_refresh=force_refresh)


@mcp.tool()
async def get_scan(scan_id: int, force_refresh: bool = False) -> str:
    """Get Nessus scan details including hosts summary from the latest run."""
    return await scans_tools.get_scan(scan_id, force_refresh=force_refresh)


@mcp.tool()
async def get_scan_status(scan_id: int, force_refresh: bool = False) -> str:
    """Get current status for a Nessus scan (completed/running/etc.)."""
    return await scans_tools.get_scan_status(scan_id, force_refresh=force_refresh)


@mcp.tool(timeout=7200.0)
async def wait_for_scan(
    scan_id: int,
    poll_interval: int = 30,
    timeout: int = 7200,
) -> str:
    """Poll scan status until completed, canceled, or aborted (or timeout)."""
    return await scans_tools.wait_for_scan(
        scan_id,
        poll_interval=poll_interval,
        timeout=timeout,
    )


@mcp.tool()
async def list_scan_templates(force_refresh: bool = False) -> str:
    """List available Nessus scan templates (policy UUIDs for create_scan)."""
    return await scans_tools.list_scan_templates(force_refresh=force_refresh)


@mcp.tool()
async def create_scan(
    name: str,
    text_targets: str,
    template_uuid: str | None = None,
    template_name: str = "advanced",
    description: str = "",
) -> str:
    """Create a Nessus scan configuration (blocked when NESSUS_READONLY=true)."""
    return await scans_tools.create_scan(
        name=name,
        text_targets=text_targets,
        template_uuid=template_uuid,
        template_name=template_name,
        description=description,
    )


@mcp.tool()
async def launch_scan(scan_id: int) -> str:
    """Launch a configured Nessus scan (blocked when NESSUS_READONLY=true)."""
    return await scans_tools.launch_scan(scan_id)


@mcp.tool()
async def stop_scan(scan_id: int) -> str:
    """Stop a running Nessus scan (blocked when NESSUS_READONLY=true)."""
    return await scans_tools.stop_scan(scan_id)


@mcp.tool(timeout=180.0)
async def sync_scan_inventory(
    scan_id: int,
    force_refresh: bool = False,
    export_format: str = "nessus",
) -> str:
    """Export scan results, parse hosts/vulns, and upsert local security inventory."""
    return await sync_tools.sync_scan_inventory(
        scan_id,
        force_refresh=force_refresh,
        export_format=export_format,
    )


@mcp.tool()
async def lookup_asset_by_ip(ip: str) -> str:
    """Lookup a host in the local security inventory by IP."""
    return await inventory_tools.lookup_asset_by_ip(ip)


@mcp.tool()
async def lookup_asset_by_hostname(hostname: str) -> str:
    """Lookup a host in the local security inventory by hostname."""
    return await inventory_tools.lookup_asset_by_hostname(hostname)


@mcp.tool()
async def search_inventory(
    ip_contains: str | None = None,
    os_contains: str | None = None,
    min_critical: int | None = None,
    min_high: int | None = None,
    limit: int = 50,
) -> str:
    """Search local inventory by IP fragment, OS, or vulnerability counts."""
    return await inventory_tools.search_inventory(
        ip_contains=ip_contains,
        os_contains=os_contains,
        min_critical=min_critical,
        min_high=min_high,
        limit=limit,
    )


@mcp.tool()
async def get_asset_vuln_summary(ip: str) -> str:
    """Get aggregated vulnerability counts for an asset from local inventory."""
    return await inventory_tools.get_asset_vuln_summary(ip)


@mcp.tool()
async def get_asset_findings(
    ip: str,
    min_severity: int | None = None,
    limit: int = 100,
) -> str:
    """List vulnerability findings for an asset from local inventory."""
    return await inventory_tools.get_asset_findings(
        ip,
        min_severity=min_severity,
        limit=limit,
    )


@mcp.tool()
async def list_high_risk_assets(limit: int = 50) -> str:
    """List assets with critical or high vulnerability counts from local inventory."""
    return await inventory_tools.list_high_risk_assets(limit=limit)


@mcp.tool()
async def nessus_request(
    method: str,
    path: str,
    query: dict[str, Any] | None = None,
    json_body: dict[str, Any] | list[Any] | None = None,
) -> str:
    """Generic Nessus REST request (escape hatch; respects NESSUS_READONLY)."""
    return await request_tools.nessus_request(
        method,
        path,
        query=query,
        json_body=json_body,
    )


@mcp.tool()
async def search_api_docs(query: str, max_results: int = 5) -> str:
    """Search local Nessus API reference (docs/API.md)."""
    return await docs_tools.search_api_docs(query, max_results=max_results)
