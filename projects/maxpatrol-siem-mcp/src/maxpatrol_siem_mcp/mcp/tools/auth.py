from __future__ import annotations

import json

from maxpatrol_siem_mcp.mcp.context import get_siem_client


async def get_access_token(force_refresh: bool = False) -> str:
    client = get_siem_client()
    payload = await client.token_manager.fetch_token_response(force_refresh=force_refresh)
    return json.dumps(payload, ensure_ascii=False, indent=2)
