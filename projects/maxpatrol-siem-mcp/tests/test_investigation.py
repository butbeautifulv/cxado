import json

import httpx
import pytest
import respx

from maxpatrol_siem_mcp.client.auth import TokenManager
from maxpatrol_siem_mcp.client.siem import SiemHttpClient
from maxpatrol_siem_mcp.mcp.context import set_siem_client
from maxpatrol_siem_mcp.mcp.tools import incidents as incidents_tools
from maxpatrol_siem_mcp.mcp.tools import investigation as investigation_tools


INCIDENT_ID = "11111111-2222-3333-4444-555555555555"


@pytest.fixture
def mock_token(settings):
    respx.post(f"{settings.token_url}").mock(
        return_value=httpx.Response(
            200,
            json={"access_token": "tok", "expires_in": 3600, "token_type": "Bearer"},
        )
    )


@pytest.mark.asyncio
@respx.mock
async def test_get_incident_uses_read_model_path(settings, mock_token) -> None:
    route = respx.get(
        f"{settings.siem_base_url_str}/api/incidentsReadModel/incidents/{INCIDENT_ID}"
    ).mock(return_value=httpx.Response(200, json={"id": INCIDENT_ID, "key": "INC-1"}))

    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    result = await incidents_tools.get_incident(INCIDENT_ID)
    assert INCIDENT_ID in result
    assert route.called


@pytest.mark.asyncio
@respx.mock
async def test_list_incident_events_uses_correct_path(settings, mock_token) -> None:
    route = respx.get(
        f"{settings.siem_base_url_str}/api/incidents/{INCIDENT_ID}/events"
    ).mock(return_value=httpx.Response(200, json={"events": [{"uuid": "e1"}]}))

    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    result = await incidents_tools.list_incident_events(INCIDENT_ID, limit=10)
    assert "events" in result
    assert route.called
    assert route.calls.last.request.url.params["limit"] == "10"


@pytest.mark.asyncio
@respx.mock
async def test_investigate_incident_composite(settings, mock_token) -> None:
    respx.get(
        f"{settings.siem_base_url_str}/api/incidentsReadModel/incidents/{INCIDENT_ID}"
    ).mock(
        return_value=httpx.Response(
            200,
            json={
                "id": INCIDENT_ID,
                "key": "INC-42",
                "status": "InProgress",
                "severity": "High",
                "detected": "2026-07-05T12:00:00Z",
                "targets": [{"name": "host1"}],
                "attackers": [],
                "correlationRuleNames": ["rule-a"],
            },
        )
    )
    respx.get(f"{settings.siem_base_url_str}/api/incidents/{INCIDENT_ID}/events").mock(
        return_value=httpx.Response(200, json={"events": [{"uuid": "linked-1"}]})
    )
    events_route = respx.post(
        f"{settings.siem_base_url_str}/api/events/v2/events"
    ).mock(return_value=httpx.Response(200, json={"totalItems": 3, "events": []}))

    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    raw = await investigation_tools.investigate_incident(
        INCIDENT_ID,
        events_limit=25,
        include_raw_events=True,
    )
    payload = json.loads(raw)

    assert payload["incident_id"] == INCIDENT_ID
    assert payload["summary"]["key"] == "INC-42"
    assert payload["summary"]["targets_count"] == 1
    assert payload["linked_events"]["events"][0]["uuid"] == "linked-1"
    assert payload["recent_events"]["totalItems"] == 3
    assert "time_window" in payload
    assert events_route.called
    body = json.loads(events_route.calls.last.request.content)
    assert "timeFrom" in body
    assert body["filter"]["select"]
    assert body["filter"]["groupBy"] == []
    assert "evidence_manifest" in payload
    assert payload["evidence_manifest"]["telemetry_level"] in {"rich", "sparse", "metadata_only"}
    assert payload["evidence_manifest"]["max_confidence"] <= 1.0


@pytest.mark.asyncio
@respx.mock
async def test_investigate_incident_with_target_assets(settings, mock_token) -> None:
    respx.get(
        f"{settings.siem_base_url_str}/api/incidentsReadModel/incidents/{INCIDENT_ID}"
    ).mock(
        return_value=httpx.Response(
            200,
            json={
                "id": INCIDENT_ID,
                "key": "INC-42",
                "detected": "2026-07-05T12:00:00Z",
                "targets": [{"addresses": ["10.0.0.5"]}],
                "attackers": [],
            },
        )
    )
    respx.get(f"{settings.siem_base_url_str}/api/incidents/{INCIDENT_ID}/events").mock(
        return_value=httpx.Response(200, json={"events": []})
    )
    respx.post(f"{settings.siem_base_url_str}/api/events/v2/events").mock(
        return_value=httpx.Response(200, json={"totalCount": 0, "events": []})
    )
    respx.post(
        f"{settings.siem_base_url_str}/api/assets_temporal_readmodel/v1/assets_grid"
    ).mock(return_value=httpx.Response(200, json={"token": "tok"}))
    respx.get(
        f"{settings.siem_base_url_str}/api/assets_temporal_readmodel/v1/assets_grid/export"
    ).mock(return_value=httpx.Response(200, text="host\nsrv"))

    client = SiemHttpClient(settings, TokenManager(settings))
    set_siem_client(client)
    raw = await investigation_tools.investigate_incident(
        INCIDENT_ID,
        include_target_assets=True,
    )
    payload = json.loads(raw)
    assert "target_assets" in payload
    assert "10.0.0.5" in payload["target_assets"]["ips"]
