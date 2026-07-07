from __future__ import annotations

import json
from typing import Any

from maxpatrol_siem_mcp.mcp.context import get_siem_client


async def get_asset_groups_hierarchy() -> str:
    """Получить иерархию групп активов."""
    client = get_siem_client()
    return await client.request_json_string(
        "GET",
        "/api/assets_temporal_readmodel/v2/groups/hierarchy",
    )


async def get_pdql_token(
    pdql: str,
    include_nested_groups: bool = True,
    selected_group_ids: list[str] | None = None,
    previous_token: str | None = None,
) -> str:
    """Получить PDQL-токен для запросов к таблице активов."""
    client = get_siem_client()
    body: dict[str, Any] = {
        "pdql": pdql,
        "includeNestedGroups": include_nested_groups,
    }
    if selected_group_ids:
        body["selectedGroupIds"] = selected_group_ids
    if previous_token:
        body["previousToken"] = previous_token
    return await client.request_json_string(
        "POST",
        "/api/assets_temporal_readmodel/v1/assets_grid",
        json_body=body,
    )


async def get_asset_metadata(
    asset_type: str,
    only_user_properties: bool | None = None,
) -> str:
    """Получить метаданные модели актива."""
    client = get_siem_client()
    params: dict[str, Any] = {}
    if only_user_properties is not None:
        params["onlyUserProperties"] = only_user_properties
    return await client.request_json_string(
        "GET",
        f"/api/assets/metadata/{asset_type}",
        params=params or None,
    )


async def export_assets_grid(
    pdql_token: str,
    grid_side: str | None = None,
) -> str:
    """Экспорт таблицы активов в CSV по PDQL-токену."""
    client = get_siem_client()
    params: dict[str, str] = {"pdqlToken": pdql_token}
    if grid_side:
        params["gridSide"] = grid_side
    return await client.request_json_string(
        "GET",
        "/api/assets_temporal_readmodel/v1/assets_grid/export",
        params=params,
    )


async def lookup_assets_by_pdql(
    pdql: str,
    include_nested_groups: bool = True,
) -> str:
    """Получить PDQL-токен и экспортировать таблицу активов."""
    token_raw = await get_pdql_token(pdql, include_nested_groups=include_nested_groups)
    token_payload = json.loads(token_raw)
    token_body = token_payload.get("body", token_payload)
    pdql_token = token_body.get("token") if isinstance(token_body, dict) else None
    if not pdql_token:
        return token_raw

    export_raw = await export_assets_grid(pdql_token)
    export_payload = json.loads(export_raw)
    result = {
        "pdql": pdql,
        "token": pdql_token,
        "export": export_payload.get("body", export_payload),
    }
    return json.dumps(result, ensure_ascii=False, indent=2)


async def lookup_assets_by_ip(ip: str) -> str:
    """Найти активы по IP-адресу."""
    pdql = (
        f"select(@Host, Host.@IpAddress, Host.@Hostname, Host.@Id) "
        f"| filter(Host.@IpAddress = '{ip}')"
    )
    return await lookup_assets_by_pdql(pdql)


async def lookup_assets_by_hostname(hostname: str) -> str:
    """Найти активы по hostname."""
    pdql = (
        f"select(@Host, Host.@IpAddress, Host.@Hostname, Host.@Id) "
        f"| filter(Host.@Hostname = '{hostname}')"
    )
    return await lookup_assets_by_pdql(pdql)
