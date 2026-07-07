from __future__ import annotations

from typing import Any

from defectdojo_mcp.mcp.context import get_defectdojo_client


def _params(**kwargs: Any) -> dict[str, Any]:
    return {k: v for k, v in kwargs.items() if v is not None}


async def list_engagements(
    *,
    product: int | None = None,
    status: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string(
        "GET",
        "/api/v2/engagements/",
        params=_params(product=product, status=status, limit=limit, offset=offset),
    )


async def get_engagement(engagement_id: int) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string("GET", f"/api/v2/engagements/{engagement_id}/")


async def create_engagement(
    name: str,
    product: int,
    target_start: str,
    target_end: str,
    description: str = "",
    status: str = "In Progress",
) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string(
        "POST",
        "/api/v2/engagements/",
        json_body={
            "name": name,
            "product": product,
            "target_start": target_start,
            "target_end": target_end,
            "description": description,
            "status": status,
        },
    )


async def close_engagement(engagement_id: int) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string("POST", f"/api/v2/engagements/{engagement_id}/close/")
