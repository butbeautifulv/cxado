from __future__ import annotations

import json
from typing import Any

from defectdojo_mcp.mcp.context import get_defectdojo_client


async def defectdojo_request(
    method: str,
    path: str,
    query: dict[str, Any] | None = None,
    json_body: dict[str, Any] | list[Any] | None = None,
    form_body: dict[str, Any] | None = None,
) -> str:
    client = get_defectdojo_client()
    result = await client.request(
        method,
        path,
        params=query,
        json_body=json_body,
        data=form_body,
    )
    return json.dumps(result, ensure_ascii=False, indent=2)
