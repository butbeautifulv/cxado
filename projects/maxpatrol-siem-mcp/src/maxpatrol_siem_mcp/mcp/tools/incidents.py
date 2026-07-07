from __future__ import annotations

from typing import Any

from maxpatrol_siem_mcp.mcp.context import get_siem_client


async def list_incidents(
    filter_body: dict[str, Any] | None = None,
    filter_time_type: str = "creation",
    limit: int = 50,
    offset: int = 0,
) -> str:
    """Получить список инцидентов (POST /api/v2/incidents)."""
    client = get_siem_client()
    body: dict[str, Any] = {
        "filterTimeType": filter_time_type,
        "limit": limit,
        "offset": offset,
        "groups": {"filterType": "no_filter"},
        "queryIds": ["all_incidents"],
        "filter": {
            "select": [
                "key",
                "name",
                "category",
                "type",
                "status",
                "created",
                "severity",
                "assigned",
            ],
            "where": "",
            "orderby": [{"field": "created", "sortOrder": "descending"}],
        },
    }
    if filter_body:
        body["filter"] = {**body["filter"], **filter_body}
    return await client.request_json_string("POST", "/api/v2/incidents", json_body=body)


async def get_incident(incident_id: str) -> str:
    """Получить данные инцидента (read model)."""
    client = get_siem_client()
    return await client.request_json_string(
        "GET",
        f"/api/incidentsReadModel/incidents/{incident_id}",
    )


async def list_incident_events(
    incident_id: str,
    limit: int = 50,
    offset: int = 0,
) -> str:
    """Получить краткий список событий, связанных с инцидентом."""
    client = get_siem_client()
    return await client.request_json_string(
        "GET",
        f"/api/incidents/{incident_id}/events",
        params={"limit": limit, "offset": offset},
    )


async def get_incident_events(incident_id: str) -> str:
    """Alias for list_incident_events (backward compatible)."""
    return await list_incident_events(incident_id)


async def get_incident_severities() -> str:
    """Справочник уровней опасности инцидентов."""
    client = get_siem_client()
    return await client.request_json_string("GET", "/api/incident_dictionaries/severities")


async def get_incident_types() -> str:
    """Справочник типов инцидентов."""
    client = get_siem_client()
    return await client.request_json_string("GET", "/api/incident_dictionaries/types")


async def get_incident_read_model_events(incident_id: str) -> str:
    """Получить события инцидента из read model (id + timestamp)."""
    client = get_siem_client()
    return await client.request_json_string(
        "GET",
        f"/api/incidentsReadModel/v2/incidents/{incident_id}/events",
    )
