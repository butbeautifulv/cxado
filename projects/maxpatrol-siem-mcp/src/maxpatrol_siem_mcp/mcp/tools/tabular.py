from __future__ import annotations

import json
from typing import Any

from maxpatrol_siem_mcp.mcp.context import get_siem_client


async def search_table_lists(
    kind: str | None = None,
    siem_id: str | None = None,
) -> str:
    """Поиск табличных списков MaxPatrol SIEM."""
    client = get_siem_client()
    params: dict[str, str] = {}
    if kind:
        params["kind"] = kind
    if siem_id:
        params["siemId"] = siem_id
    return await client.request_json_string(
        "GET",
        "/api/events/v2/table_lists",
        params=params or None,
    )


async def get_table_list_info(
    list_token: str,
    siem_id: str | None = None,
) -> str:
    """Получить информацию о табличном списке по токену."""
    client = get_siem_client()
    params: dict[str, str] = {}
    if siem_id:
        params["siemId"] = siem_id
    return await client.request_json_string(
        "GET",
        f"/api/events/v2/table_lists/{list_token}",
        params=params or None,
    )


async def export_table_list(
    list_name: str,
    where: str | None = None,
    select: list[str] | None = None,
    limit: int = 50,
    siem_id: str | None = None,
) -> str:
    """Экспорт записей табличного списка (IOC lookup)."""
    client = get_siem_client()
    params: dict[str, str] = {}
    if siem_id:
        params["siemId"] = siem_id

    field_names = select
    if field_names is None:
        lists_raw = await search_table_lists(siem_id=siem_id)
        lists_payload = json.loads(lists_raw)
        lists_body = lists_payload.get("body", lists_payload)
        items = lists_body if isinstance(lists_body, list) else []
        list_token = None
        for item in items:
            if isinstance(item, dict) and item.get("name") == list_name:
                list_token = item.get("token") or item.get("id")
                break
        if list_token:
            info_raw = await get_table_list_info(str(list_token), siem_id=siem_id)
            info_payload = json.loads(info_raw)
            info_body = info_payload.get("body", info_payload)
            fields = info_body.get("fields", []) if isinstance(info_body, dict) else []
            field_names = [f["name"] for f in fields if isinstance(f, dict) and "name" in f]

    body: dict[str, Any] = {
        "filter": {
            "select": field_names or ["*"],
        },
        "limit": limit,
    }
    if where:
        body["filter"]["where"] = where

    return await client.request_json_string(
        "POST",
        f"/api/events/v1/table_lists/{list_name}/export",
        params=params or None,
        json_body=body,
    )
