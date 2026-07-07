from __future__ import annotations

from typing import Any

from defectdojo_mcp.mcp.context import get_defectdojo_client


def _params(**kwargs: Any) -> dict[str, Any]:
    return {k: v for k, v in kwargs.items() if v is not None}


async def list_tests(
    *,
    engagement: int | None = None,
    test_type: int | None = None,
    limit: int = 50,
    offset: int = 0,
) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string(
        "GET",
        "/api/v2/tests/",
        params=_params(engagement=engagement, test_type=test_type, limit=limit, offset=offset),
    )


async def get_test(test_id: int) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string("GET", f"/api/v2/tests/{test_id}/")


async def create_test(
    engagement: int,
    title: str,
    test_type: int,
    target_start: str | None = None,
    target_end: str | None = None,
    description: str = "",
) -> str:
    client = get_defectdojo_client()
    body: dict[str, Any] = {
        "engagement": engagement,
        "title": title,
        "test_type": test_type,
        "description": description,
    }
    if target_start is not None:
        body["target_start"] = target_start
    if target_end is not None:
        body["target_end"] = target_end
    return await client.request_json_string("POST", "/api/v2/tests/", json_body=body)
