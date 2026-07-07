from __future__ import annotations

import json
from typing import Any

from tenable_mcp.mcp.context import get_nessus_client


async def nessus_request(
    method: str,
    path: str,
    query: dict[str, Any] | None = None,
    json_body: dict[str, Any] | list[Any] | None = None,
) -> str:
    client = get_nessus_client()
    result = await client.request(
        method,
        path,
        params=query,
        json_body=json_body,
    )
    if isinstance(result, (dict, list)):
        return json.dumps(result, ensure_ascii=False, indent=2)
    return str(result)
