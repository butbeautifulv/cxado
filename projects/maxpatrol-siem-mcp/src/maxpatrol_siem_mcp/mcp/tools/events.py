from __future__ import annotations

from typing import Any

from maxpatrol_siem_mcp.mcp.context import get_siem_client

EVENT_DETAIL_SELECT = [
    "time",
    "uuid",
    "id",
    "text",
    "event_src.host",
    "event_src.ip",
    "src.ip",
    "dst.ip",
    "src.host",
    "dst.host",
    "action",
    "status",
    "importance",
    "category.generic",
    "correlation_name",
    "object.type",
    "object.name",
    "object.value",
    "subject.process.cmdline",
    "subject.process.name",
    "subject.process.id",
    "object.process.cmdline",
    "object.process.name",
    "object.process.id",
    "subject.account.name",
    "object.account.name",
]

EVENT_DETAIL_SELECT_MINIMAL = EVENT_DETAIL_SELECT[:18]


def default_events_body(
    *,
    time_from: int | None = None,
    time_to: int | None = None,
    where: str | None = None,
    select: list[str] | None = None,
    order_desc: bool = False,
) -> dict[str, Any]:
    import time

    now = int(time.time())
    body: dict[str, Any] = {
        "timeFrom": time_from if time_from is not None else now - 86400,
        "timeTo": time_to if time_to is not None else now,
        "filter": {
            "aggregateBy": [],
            "distributeBy": [],
            "groupBy": [],
            "select": select or EVENT_DETAIL_SELECT,
        },
    }
    if where:
        body["filter"]["where"] = where
    if order_desc:
        body["filter"]["orderBy"] = [{"field": "time", "sortOrder": "descending"}]
    return body


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
    """Получить список событий (POST /api/events/v2/events)."""
    client = get_siem_client()
    params: dict[str, Any] = {"limit": limit, "offset": offset}
    if group_ids:
        params["groupIds"] = group_ids
    if incident_id:
        params["incidentId"] = incident_id
    if recursive is not None:
        params["recursive"] = recursive
    if token:
        params["token"] = token

    json_body = filter_body or default_events_body(time_from=time_from, time_to=time_to)
    return await client.request_json_string(
        "POST",
        "/api/events/v2/events",
        params=params,
        json_body=json_body,
    )


async def search_events(
    where: str,
    limit: int = 50,
    offset: int = 0,
    time_from: int | None = None,
    time_to: int | None = None,
    incident_id: str | None = None,
    group_ids: list[str] | None = None,
) -> str:
    """Поиск событий по PDQL-предикату where."""
    filter_body = default_events_body(
        time_from=time_from,
        time_to=time_to,
        where=where,
        order_desc=True,
    )
    return await list_events(
        limit=limit,
        offset=offset,
        filter_body=filter_body,
        group_ids=group_ids,
        incident_id=incident_id,
        time_from=time_from,
        time_to=time_to,
    )


async def get_event_by_uuid(
    event_uuid: str,
    time_from: int | None = None,
    time_to: int | None = None,
) -> str:
    """Получить событие по UUID."""
    return await search_events(
        where=f'uuid = "{event_uuid}"',
        limit=1,
        offset=0,
        time_from=time_from,
        time_to=time_to,
    )


async def list_aggregated_events(
    time_from: int,
    time_to: int | None = None,
    filter_body: dict[str, Any] | None = None,
    limit: int = 1000,
    group_ids: list[str] | None = None,
    incident_id: str | None = None,
    recursive: bool | None = None,
) -> str:
    """Получить агрегированные события (POST /api/events/v2/events/aggregation)."""
    client = get_siem_client()
    params: dict[str, Any] = {"limit": limit}
    if group_ids:
        params["groupIds"] = group_ids
    if incident_id:
        params["incidentId"] = incident_id
    if recursive is not None:
        params["recursive"] = recursive

    body: dict[str, Any] = {
        "timeFrom": time_from,
        "filter": {
            "groupBy": ["category.generic"],
            "aggregateBy": [{"function": "COUNT", "unique": False, "field": "*"}],
            "distributeBy": [{"field": "time", "granularity": "1h"}],
        },
    }
    if time_to is not None:
        body["timeTo"] = time_to
    if filter_body:
        body["filter"].update(filter_body)

    return await client.request_json_string(
        "POST",
        "/api/events/v2/events/aggregation",
        params=params,
        json_body=body,
    )


async def get_incident_events(incident_id: str) -> str:
    """Alias — use list_incident_events from incidents module."""
    from maxpatrol_siem_mcp.mcp.tools import incidents as incidents_tools

    return await incidents_tools.list_incident_events(incident_id)
