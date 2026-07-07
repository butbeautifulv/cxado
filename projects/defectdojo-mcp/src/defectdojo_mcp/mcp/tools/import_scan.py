from __future__ import annotations

import json
from typing import Any

from defectdojo_mcp.mcp.context import get_defectdojo_client


def _multipart_fields(**kwargs: Any) -> dict[str, Any]:
    return {k: v for k, v in kwargs.items() if v is not None}


async def import_scan(
    *,
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
    client = get_defectdojo_client()
    _, content, name = client.decode_file_payload(
        file_path=file_path,
        file_base64=file_base64,
        file_name=file_name,
    )
    data = _multipart_fields(
        scan_type=scan_type,
        product=product,
        engagement=engagement,
        test=test,
        active=str(active).lower(),
        verified=str(verified).lower(),
        minimum_severity=minimum_severity,
        auto_create_context=str(auto_create_context).lower(),
        product_name=product_name,
        engagement_name=engagement_name,
        test_title=test_title,
        build_id=build_id,
        branch_tag=branch_tag,
        commit_hash=commit_hash,
    )
    result = await client.request(
        "POST",
        "/api/v2/import-scan/",
        data=data,
        files={"file": (name, content)},
    )
    return json.dumps(result, ensure_ascii=False, indent=2)


async def reimport_scan(
    *,
    scan_type: str,
    test: int,
    file_path: str | None = None,
    file_base64: str | None = None,
    file_name: str = "scan_report.json",
    active: bool = True,
    verified: bool = False,
    minimum_severity: str | None = None,
) -> str:
    client = get_defectdojo_client()
    _, content, name = client.decode_file_payload(
        file_path=file_path,
        file_base64=file_base64,
        file_name=file_name,
    )
    data = _multipart_fields(
        scan_type=scan_type,
        test=test,
        active=str(active).lower(),
        verified=str(verified).lower(),
        minimum_severity=minimum_severity,
    )
    result = await client.request(
        "POST",
        "/api/v2/reimport-scan/",
        data=data,
        files={"file": (name, content)},
    )
    return json.dumps(result, ensure_ascii=False, indent=2)


async def preview_import_scan(
    *,
    scan_type: str,
    file_path: str | None = None,
    file_base64: str | None = None,
    file_name: str = "scan_report.json",
    product: int | None = None,
    engagement: int | None = None,
) -> str:
    client = get_defectdojo_client()
    _, content, name = client.decode_file_payload(
        file_path=file_path,
        file_base64=file_base64,
        file_name=file_name,
    )
    data = _multipart_fields(scan_type=scan_type, product=product, engagement=engagement)
    result = await client.request(
        "POST",
        "/api/v2/import-scan/preview/",
        data=data,
        files={"file": (name, content)},
    )
    return json.dumps(result, ensure_ascii=False, indent=2)
