from __future__ import annotations

from typing import Any

from maxpatrol_siem_mcp.mcp.context import get_siem_client


def _mc_client():
    return get_siem_client()


async def list_user_action_categories() -> str:
    """Получить дерево категорий действий пользователей."""
    client = _mc_client()
    return await client.request_json_string(
        "GET",
        "/ptms/api/ual/v2/action_categories",
        base_url=client.mc_base_url,
    )


async def list_user_actions(
    limit: int,
    offset: int = 0,
    time_from: str | None = None,
    time_to: str | None = None,
) -> str:
    """Получить журнал действий пользователей."""
    client = _mc_client()
    params: dict[str, Any] = {"limit": limit, "offset": offset}
    if time_from:
        params["timeFrom"] = time_from
    if time_to:
        params["timeTo"] = time_to
    return await client.request_json_string(
        "GET",
        "/ptms/api/ual/v2/user_actions",
        params=params,
        base_url=client.mc_base_url,
    )


async def search_user_actions(
    filter_body: dict[str, Any],
    limit: int,
    offset: int = 0,
) -> str:
    """Поиск действий пользователей по фильтру."""
    client = _mc_client()
    return await client.request_json_string(
        "POST",
        "/ptms/api/ual/v2/user_actions",
        params={"limit": limit, "offset": offset},
        json_body={"filter": filter_body},
        base_url=client.mc_base_url,
    )
