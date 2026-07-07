from __future__ import annotations

from typing import Any

from defectdojo_mcp.mcp.context import get_defectdojo_client


def _params(**kwargs: Any) -> dict[str, Any]:
    return {k: v for k, v in kwargs.items() if v is not None}


async def list_findings(
    *,
    severity: str | None = None,
    active: bool | None = None,
    verified: bool | None = None,
    duplicate: bool | None = None,
    product: int | None = None,
    test: int | None = None,
    limit: int = 50,
    offset: int = 0,
) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string(
        "GET",
        "/api/v2/findings/",
        params=_params(
            severity=severity,
            active=active,
            verified=verified,
            duplicate=duplicate,
            product=product,
            test=test,
            limit=limit,
            offset=offset,
        ),
    )


async def get_finding(finding_id: int) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string("GET", f"/api/v2/findings/{finding_id}/")


async def update_finding(finding_id: int, fields: dict[str, Any]) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string(
        "PATCH",
        f"/api/v2/findings/{finding_id}/",
        json_body=fields,
    )


async def close_finding(finding_id: int) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string("POST", f"/api/v2/findings/{finding_id}/close/")


async def verify_finding(finding_id: int) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string("POST", f"/api/v2/findings/{finding_id}/verify/")


async def add_finding_note(finding_id: int, entry: str, private: bool = False) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string(
        "POST",
        f"/api/v2/findings/{finding_id}/notes/",
        json_body={"entry": entry, "private": private},
    )


async def list_finding_notes(finding_id: int, limit: int = 50, offset: int = 0) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string(
        "GET",
        f"/api/v2/findings/{finding_id}/notes/",
        params={"limit": limit, "offset": offset},
    )


async def accept_finding_risks(finding_ids: list[int]) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string(
        "POST",
        "/api/v2/findings/accept_risks/",
        json_body={"finding_ids": finding_ids},
    )
