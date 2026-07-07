from __future__ import annotations

from typing import Any

from fastmcp import FastMCP

from defectdojo_mcp.mcp.tools import docs as docs_tools
from defectdojo_mcp.mcp.tools import engagements as engagement_tools
from defectdojo_mcp.mcp.tools import findings as finding_tools
from defectdojo_mcp.mcp.tools import import_scan as import_tools
from defectdojo_mcp.mcp.tools import products as product_tools
from defectdojo_mcp.mcp.tools import request as request_tools
from defectdojo_mcp.mcp.tools import tests as test_tools
from defectdojo_mcp.mcp.tools import triage as triage_tools

mcp = FastMCP("defectdojo-mcp")


@mcp.tool()
async def defectdojo_request(
    method: str,
    path: str,
    query: dict[str, Any] | None = None,
    json_body: dict[str, Any] | list[Any] | None = None,
    form_body: dict[str, Any] | None = None,
) -> str:
    """Generic DefectDojo API v2 request. Prefer typed tools when available."""
    return await request_tools.defectdojo_request(
        method,
        path,
        query=query,
        json_body=json_body,
        form_body=form_body,
    )


@mcp.tool()
async def search_api_docs(query: str, max_results: int = 5) -> str:
    """Search local DefectDojo API documentation."""
    return await docs_tools.search_api_docs(query, max_results=max_results)


@mcp.tool()
async def list_findings(
    severity: str | None = None,
    active: bool | None = None,
    verified: bool | None = None,
    duplicate: bool | None = None,
    product: int | None = None,
    test: int | None = None,
    limit: int = 50,
    offset: int = 0,
) -> str:
    """List vulnerability findings (triage queue)."""
    return await finding_tools.list_findings(
        severity=severity,
        active=active,
        verified=verified,
        duplicate=duplicate,
        product=product,
        test=test,
        limit=limit,
        offset=offset,
    )


@mcp.tool()
async def get_finding(finding_id: int) -> str:
    """Get one finding by ID."""
    return await finding_tools.get_finding(finding_id)


@mcp.tool()
async def update_finding(finding_id: int, fields: dict[str, Any]) -> str:
    """Patch finding fields (severity, active, verified, mitigated, false_p, out_of_scope)."""
    return await finding_tools.update_finding(finding_id, fields)


@mcp.tool()
async def close_finding(finding_id: int) -> str:
    """Close a finding."""
    return await finding_tools.close_finding(finding_id)


@mcp.tool()
async def verify_finding(finding_id: int) -> str:
    """Mark finding as verified."""
    return await finding_tools.verify_finding(finding_id)


@mcp.tool()
async def add_finding_note(finding_id: int, entry: str, private: bool = False) -> str:
    """Add triage note to a finding."""
    return await finding_tools.add_finding_note(finding_id, entry, private=private)


@mcp.tool()
async def list_finding_notes(finding_id: int, limit: int = 50, offset: int = 0) -> str:
    """List notes on a finding."""
    return await finding_tools.list_finding_notes(finding_id, limit=limit, offset=offset)


@mcp.tool()
async def accept_finding_risks(finding_ids: list[int]) -> str:
    """Bulk risk acceptance for findings."""
    return await finding_tools.accept_finding_risks(finding_ids)


@mcp.tool()
async def triage_finding(finding_id: int) -> str:
    """Composite triage context: finding, notes, test, engagement, product."""
    return await triage_tools.triage_finding(finding_id)


@mcp.tool()
async def list_products(name: str | None = None, limit: int = 50, offset: int = 0) -> str:
    """List DefectDojo products."""
    return await product_tools.list_products(name=name, limit=limit, offset=offset)


@mcp.tool()
async def get_product(product_id: int) -> str:
    """Get product by ID."""
    return await product_tools.get_product(product_id)


@mcp.tool()
async def create_product(name: str, description: str = "", prod_type: int | None = None) -> str:
    """Create a new product."""
    return await product_tools.create_product(name, description=description, prod_type=prod_type)


@mcp.tool()
async def list_engagements(
    product: int | None = None,
    status: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> str:
    """List engagements, optionally filtered by product."""
    return await engagement_tools.list_engagements(
        product=product,
        status=status,
        limit=limit,
        offset=offset,
    )


@mcp.tool()
async def get_engagement(engagement_id: int) -> str:
    """Get engagement by ID."""
    return await engagement_tools.get_engagement(engagement_id)


@mcp.tool()
async def create_engagement(
    name: str,
    product: int,
    target_start: str,
    target_end: str,
    description: str = "",
    status: str = "In Progress",
) -> str:
    """Create engagement for a product."""
    return await engagement_tools.create_engagement(
        name,
        product,
        target_start,
        target_end,
        description=description,
        status=status,
    )


@mcp.tool()
async def close_engagement(engagement_id: int) -> str:
    """Close an engagement."""
    return await engagement_tools.close_engagement(engagement_id)


@mcp.tool()
async def list_tests(
    engagement: int | None = None,
    test_type: int | None = None,
    limit: int = 50,
    offset: int = 0,
) -> str:
    """List tests (scanner runs)."""
    return await test_tools.list_tests(
        engagement=engagement,
        test_type=test_type,
        limit=limit,
        offset=offset,
    )


@mcp.tool()
async def get_test(test_id: int) -> str:
    """Get test by ID."""
    return await test_tools.get_test(test_id)


@mcp.tool()
async def create_test(
    engagement: int,
    title: str,
    test_type: int,
    target_start: str | None = None,
    target_end: str | None = None,
    description: str = "",
) -> str:
    """Create a test under an engagement."""
    return await test_tools.create_test(
        engagement,
        title,
        test_type,
        target_start=target_start,
        target_end=target_end,
        description=description,
    )


@mcp.tool()
async def import_scan(
    scan_type: str,
    file_path: str | None = None,
    file_base64: str | None = None,
    file_name: str = "scan_report.json",
    product: int | None = None,
    engagement: int | None = None,
    test: int | None = None,
    active: bool = True,
    verified: bool = False,
    minimum_severity: str | None = None,
    auto_create_context: bool = False,
    product_name: str | None = None,
    engagement_name: str | None = None,
    test_title: str | None = None,
    build_id: str | None = None,
    branch_tag: str | None = None,
    commit_hash: str | None = None,
) -> str:
    """Import scanner report (multipart). Provide file_path or file_base64."""
    return await import_tools.import_scan(
        scan_type=scan_type,
        file_path=file_path,
        file_base64=file_base64,
        file_name=file_name,
        product=product,
        engagement=engagement,
        test=test,
        active=active,
        verified=verified,
        minimum_severity=minimum_severity,
        auto_create_context=auto_create_context,
        product_name=product_name,
        engagement_name=engagement_name,
        test_title=test_title,
        build_id=build_id,
        branch_tag=branch_tag,
        commit_hash=commit_hash,
    )


@mcp.tool()
async def reimport_scan(
    scan_type: str,
    test: int,
    file_path: str | None = None,
    file_base64: str | None = None,
    file_name: str = "scan_report.json",
    active: bool = True,
    verified: bool = False,
    minimum_severity: str | None = None,
) -> str:
    """Re-import scan results into an existing test."""
    return await import_tools.reimport_scan(
        scan_type=scan_type,
        test=test,
        file_path=file_path,
        file_base64=file_base64,
        file_name=file_name,
        active=active,
        verified=verified,
        minimum_severity=minimum_severity,
    )


@mcp.tool()
async def preview_import_scan(
    scan_type: str,
    file_path: str | None = None,
    file_base64: str | None = None,
    file_name: str = "scan_report.json",
    product: int | None = None,
    engagement: int | None = None,
) -> str:
    """Dry-run import scan preview."""
    return await import_tools.preview_import_scan(
        scan_type=scan_type,
        file_path=file_path,
        file_base64=file_base64,
        file_name=file_name,
        product=product,
        engagement=engagement,
    )
