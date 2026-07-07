from __future__ import annotations

import json
from typing import Any

from maxpatrol_siem_mcp.mcp.context import get_siem_client


async def siem_request(
    method: str,
    path: str,
    query: dict[str, Any] | None = None,
    json_body: dict[str, Any] | list[Any] | None = None,
    form_body: dict[str, Any] | None = None,
) -> str:
    client = get_siem_client()
    result = await client.request(
        method,
        path,
        params=query,
        json_body=json_body,
        form_body=form_body,
    )
    return json.dumps(result, ensure_ascii=False, indent=2)
