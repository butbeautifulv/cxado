from __future__ import annotations

import json

from defectdojo_mcp.mcp.context import get_defectdojo_client


async def triage_finding(finding_id: int) -> str:
    """Composite context for vulnerability triage: finding, notes, test, product, engagement."""
    client = get_defectdojo_client()

    finding_resp = await client.request("GET", f"/api/v2/findings/{finding_id}/")
    finding_body = finding_resp.get("body") or {}

    notes_resp = await client.request(
        "GET",
        f"/api/v2/findings/{finding_id}/notes/",
        params={"limit": 20, "offset": 0},
    )

    test_data = None
    product_data = None
    engagement_data = None

    test_id = finding_body.get("test")
    if isinstance(test_id, int):
        test_resp = await client.request("GET", f"/api/v2/tests/{test_id}/")
        test_data = test_resp.get("body")
        engagement_id = (test_data or {}).get("engagement")
        if isinstance(engagement_id, int):
            engagement_resp = await client.request("GET", f"/api/v2/engagements/{engagement_id}/")
            engagement_data = engagement_resp.get("body")
            product_id = (engagement_data or {}).get("product")
            if isinstance(product_id, int):
                product_resp = await client.request("GET", f"/api/v2/products/{product_id}/")
                product_data = product_resp.get("body")

    endpoints = finding_body.get("endpoints") or []

    payload = {
        "finding_id": finding_id,
        "finding": finding_body,
        "notes": notes_resp.get("body"),
        "test": test_data,
        "engagement": engagement_data,
        "product": product_data,
        "endpoint_ids": endpoints,
    }
    return json.dumps(payload, ensure_ascii=False, indent=2)
