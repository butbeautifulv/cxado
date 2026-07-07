from __future__ import annotations

from maxpatrol_siem_mcp.mcp.context import get_siem_client


async def list_scopes() -> str:
    """Получить список инфраструктур (scopes)."""
    client = get_siem_client()
    return await client.request_json_string("GET", "/api/scopes/v2/scopes")


async def get_incident_filters_hierarchy() -> str:
    """Получить дерево сохранённых фильтров инцидентов."""
    client = get_siem_client()
    return await client.request_json_string("GET", "/api/v1/incidents/filters_hierarchy")
