from __future__ import annotations

from typing import Any

from fastmcp import FastMCP

from maxpatrol_siem_mcp.mcp.tools import assets as assets_tools
from maxpatrol_siem_mcp.mcp.tools import audit as audit_tools
from maxpatrol_siem_mcp.mcp.tools import auth as auth_tools
from maxpatrol_siem_mcp.mcp.tools import context as context_tools
from maxpatrol_siem_mcp.mcp.tools import docs as docs_tools
from maxpatrol_siem_mcp.mcp.tools import events as events_tools
from maxpatrol_siem_mcp.mcp.tools import incidents as incidents_tools
from maxpatrol_siem_mcp.mcp.tools import investigation as investigation_tools
from maxpatrol_siem_mcp.mcp.tools import request as request_tools
from maxpatrol_siem_mcp.mcp.tools import tabular as tabular_tools

mcp = FastMCP("maxpatrol-siem-mcp")


@mcp.tool()
async def siem_request(
    method: str,
    path: str,
    query: dict[str, Any] | None = None,
    json_body: dict[str, Any] | list[Any] | None = None,
    form_body: dict[str, Any] | None = None,
) -> str:
    """Универсальный запрос к MaxPatrol SIEM REST API.

    Do NOT use if a typed tool exists (investigate_incident, search_events, list_incidents, …).

    Args:
        method: HTTP-метод (GET, POST, PUT, DELETE, ...).
        path: Путь относительно корневого URL API, например /api/v2/incidents.
        query: Query-параметры.
        json_body: JSON-тело запроса.
        form_body: Form-urlencoded тело запроса.
    """
    return await request_tools.siem_request(
        method,
        path,
        query=query,
        json_body=json_body,
        form_body=form_body,
    )


@mcp.tool()
async def get_access_token(force_refresh: bool = False) -> str:
    """Получить OAuth access token для MaxPatrol SIEM (POST /connect/token)."""
    return await auth_tools.get_access_token(force_refresh=force_refresh)


@mcp.tool()
async def list_incidents(
    filter_body: dict[str, Any] | None = None,
    filter_time_type: str = "creation",
    limit: int = 50,
    offset: int = 0,
) -> str:
    """Use when triaging the incident queue: list MaxPatrol SIEM incidents (New/InProgress)."""
    return await incidents_tools.list_incidents(
        filter_body=filter_body,
        filter_time_type=filter_time_type,
        limit=limit,
        offset=offset,
    )


@mcp.tool()
async def get_incident(incident_id: str) -> str:
    """Получить данные инцидента по UUID."""
    return await incidents_tools.get_incident(incident_id)


@mcp.tool()
async def list_events(
    limit: int,
    offset: int,
    filter_body: dict[str, Any] | None = None,
    group_ids: list[str] | None = None,
    incident_id: str | None = None,
    recursive: bool | None = None,
    token: str | None = None,
    time_from: int | None = None,
    time_to: int | None = None,
) -> str:
    """Получить список событий MaxPatrol SIEM."""
    return await events_tools.list_events(
        limit=limit,
        offset=offset,
        filter_body=filter_body,
        group_ids=group_ids,
        incident_id=incident_id,
        recursive=recursive,
        token=token,
        time_from=time_from,
        time_to=time_to,
    )


@mcp.tool()
async def list_aggregated_events(
    time_from: int,
    time_to: int | None = None,
    filter_body: dict[str, Any] | None = None,
    limit: int = 1000,
    group_ids: list[str] | None = None,
    incident_id: str | None = None,
    recursive: bool | None = None,
) -> str:
    """Получить агрегированные события для таймлайна расследования."""
    return await events_tools.list_aggregated_events(
        time_from=time_from,
        time_to=time_to,
        filter_body=filter_body,
        limit=limit,
        group_ids=group_ids,
        incident_id=incident_id,
        recursive=recursive,
    )


@mcp.tool()
async def list_incident_events(
    incident_id: str,
    limit: int = 50,
    offset: int = 0,
) -> str:
    """Получить краткий список событий, связанных с инцидентом."""
    return await incidents_tools.list_incident_events(
        incident_id,
        limit=limit,
        offset=offset,
    )


@mcp.tool()
async def get_incident_events(incident_id: str) -> str:
    """Получить события, связанные с инцидентом (alias для list_incident_events)."""
    return await incidents_tools.get_incident_events(incident_id)


@mcp.tool()
async def get_incident_severities() -> str:
    """Справочник уровней опасности инцидентов."""
    return await incidents_tools.get_incident_severities()


@mcp.tool()
async def get_incident_types() -> str:
    """Справочник типов инцидентов."""
    return await incidents_tools.get_incident_types()


@mcp.tool()
async def get_incident_read_model_events(incident_id: str) -> str:
    """Получить события инцидента из read model."""
    return await incidents_tools.get_incident_read_model_events(incident_id)


@mcp.tool()
async def list_scopes() -> str:
    """Получить список инфраструктур (scopes)."""
    return await context_tools.list_scopes()


@mcp.tool()
async def get_incident_filters_hierarchy() -> str:
    """Получить дерево сохранённых фильтров инцидентов."""
    return await context_tools.get_incident_filters_hierarchy()


@mcp.tool()
async def search_events(
    where: str,
    limit: int = 50,
    offset: int = 0,
    time_from: int | None = None,
    time_to: int | None = None,
    incident_id: str | None = None,
    group_ids: list[str] | None = None,
) -> str:
    """Search SIEM events by PDQL where clause. Use after investigate_incident for correlation."""
    return await events_tools.search_events(
        where=where,
        limit=limit,
        offset=offset,
        time_from=time_from,
        time_to=time_to,
        incident_id=incident_id,
        group_ids=group_ids,
    )


@mcp.tool()
async def get_event_by_uuid(
    event_uuid: str,
    time_from: int | None = None,
    time_to: int | None = None,
) -> str:
    """Получить событие по UUID."""
    return await events_tools.get_event_by_uuid(
        event_uuid,
        time_from=time_from,
        time_to=time_to,
    )


@mcp.tool()
async def get_asset_groups_hierarchy() -> str:
    """Получить иерархию групп активов."""
    return await assets_tools.get_asset_groups_hierarchy()


@mcp.tool()
async def get_pdql_token(
    pdql: str,
    include_nested_groups: bool = True,
    selected_group_ids: list[str] | None = None,
    previous_token: str | None = None,
) -> str:
    """Получить PDQL-токен для запросов к таблице активов."""
    return await assets_tools.get_pdql_token(
        pdql=pdql,
        include_nested_groups=include_nested_groups,
        selected_group_ids=selected_group_ids,
        previous_token=previous_token,
    )


@mcp.tool()
async def get_asset_metadata(
    asset_type: str,
    only_user_properties: bool | None = None,
) -> str:
    """Получить метаданные модели актива."""
    return await assets_tools.get_asset_metadata(
        asset_type,
        only_user_properties=only_user_properties,
    )


@mcp.tool()
async def export_assets_grid(
    pdql_token: str,
    grid_side: str | None = None,
) -> str:
    """Экспорт таблицы активов в CSV по PDQL-токену."""
    return await assets_tools.export_assets_grid(pdql_token, grid_side=grid_side)


@mcp.tool()
async def lookup_assets_by_pdql(
    pdql: str,
    include_nested_groups: bool = True,
) -> str:
    """Получить активы по PDQL-запросу (token + CSV export)."""
    return await assets_tools.lookup_assets_by_pdql(
        pdql,
        include_nested_groups=include_nested_groups,
    )


@mcp.tool()
async def lookup_assets_by_ip(ip: str) -> str:
    """Найти активы по IP-адресу."""
    return await assets_tools.lookup_assets_by_ip(ip)


@mcp.tool()
async def lookup_assets_by_hostname(hostname: str) -> str:
    """Найти активы по hostname."""
    return await assets_tools.lookup_assets_by_hostname(hostname)


@mcp.tool()
async def search_table_lists(
    kind: str | None = None,
    siem_id: str | None = None,
) -> str:
    """Поиск табличных списков MaxPatrol SIEM."""
    return await tabular_tools.search_table_lists(kind=kind, siem_id=siem_id)


@mcp.tool()
async def get_table_list_info(
    list_token: str,
    siem_id: str | None = None,
) -> str:
    """Получить информацию о табличном списке по токену."""
    return await tabular_tools.get_table_list_info(list_token, siem_id=siem_id)


@mcp.tool()
async def export_table_list(
    list_name: str,
    where: str | None = None,
    select: list[str] | None = None,
    limit: int = 50,
    siem_id: str | None = None,
) -> str:
    """Экспорт записей табличного списка (IOC lookup)."""
    return await tabular_tools.export_table_list(
        list_name,
        where=where,
        select=select,
        limit=limit,
        siem_id=siem_id,
    )


@mcp.tool()
async def list_user_action_categories() -> str:
    """Получить дерево категорий действий пользователей."""
    return await audit_tools.list_user_action_categories()


@mcp.tool()
async def list_user_actions(
    limit: int,
    offset: int = 0,
    time_from: str | None = None,
    time_to: str | None = None,
) -> str:
    """Получить журнал действий пользователей."""
    return await audit_tools.list_user_actions(
        limit=limit,
        offset=offset,
        time_from=time_from,
        time_to=time_to,
    )


@mcp.tool()
async def search_user_actions(
    filter_body: dict[str, Any],
    limit: int,
    offset: int = 0,
) -> str:
    """Поиск действий пользователей по фильтру."""
    return await audit_tools.search_user_actions(
        filter_body=filter_body,
        limit=limit,
        offset=offset,
    )


@mcp.tool(timeout=180.0)
async def investigate_incident(
    incident_id: str,
    events_limit: int = 20,
    include_raw_events: bool = True,
    include_ioc_checks: bool = False,
    include_target_assets: bool = False,
) -> str:
    """Use FIRST when triaging a SIEM incident by ID — primary investigation entry point."""
    return await investigation_tools.investigate_incident(
        incident_id,
        events_limit=events_limit,
        include_raw_events=include_raw_events,
        include_ioc_checks=include_ioc_checks,
        include_target_assets=include_target_assets,
    )


@mcp.tool()
async def search_api_docs(query: str, max_results: int = 5) -> str:
    """Поиск по локальной справке MaxPatrol SIEM API (docs/API.md)."""
    return await docs_tools.search_api_docs(query, max_results=max_results)
