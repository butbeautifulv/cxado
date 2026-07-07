from __future__ import annotations

import asyncio
import json
import re
from datetime import datetime
from typing import Any

from maxpatrol_siem_mcp.evidence.manifest import build_investigation_manifest
from maxpatrol_siem_mcp.mcp.tools import assets as assets_tools
from maxpatrol_siem_mcp.mcp.tools import events as events_tools
from maxpatrol_siem_mcp.mcp.tools import incidents as incidents_tools
from maxpatrol_siem_mcp.mcp.tools import tabular as tabular_tools

_IP_RE = re.compile(r"^\d{1,3}(?:\.\d{1,3}){3}$")
_MAX_TARGETS = 3


def _parse_iso_timestamp(value: str | None) -> int | None:
    if not value:
        return None
    try:
        normalized = value.replace("Z", "+00:00")
        return int(datetime.fromisoformat(normalized).timestamp())
    except ValueError:
        return None


def _incident_time_window(incident_body: dict[str, Any]) -> tuple[int, int]:
    import time

    now = int(time.time())
    detected = _parse_iso_timestamp(incident_body.get("detected"))
    created = _parse_iso_timestamp(incident_body.get("created"))
    anchor = detected or created or now
    return anchor - 86400, anchor + 86400


def _build_summary(incident_body: dict[str, Any]) -> dict[str, Any]:
    targets = incident_body.get("targets") or []
    attackers = incident_body.get("attackers") or []
    return {
        "id": incident_body.get("id"),
        "key": incident_body.get("key"),
        "name": incident_body.get("name"),
        "status": incident_body.get("status"),
        "severity": incident_body.get("severity"),
        "category": incident_body.get("category"),
        "type": incident_body.get("type"),
        "targets_count": len(targets) if isinstance(targets, list) else 0,
        "attackers_count": len(attackers) if isinstance(attackers, list) else 0,
        "correlation_rules": incident_body.get("correlationRuleNames") or [],
        "is_confirmed": incident_body.get("isConfirmed"),
    }


def _extract_target_values(targets: list[Any]) -> tuple[list[str], list[str]]:
    ips: list[str] = []
    hosts: list[str] = []
    for target in targets:
        if not isinstance(target, dict):
            continue
        for addr in target.get("addresses") or []:
            if isinstance(addr, str) and _IP_RE.match(addr) and addr not in ips:
                ips.append(addr)
        for other in target.get("others") or []:
            if isinstance(other, str) and other not in hosts:
                hosts.append(other)
        name = target.get("name")
        if isinstance(name, str) and name not in hosts:
            hosts.append(name)
    return ips, hosts


async def _lookup_target_assets(targets: list[Any]) -> dict[str, Any]:
    ips, hosts = _extract_target_values(targets)
    results: dict[str, Any] = {"ips": {}, "hosts": {}}
    for ip in ips[:_MAX_TARGETS]:
        try:
            results["ips"][ip] = json.loads(await assets_tools.lookup_assets_by_ip(ip))
        except Exception as exc:  # noqa: BLE001
            results["ips"][ip] = {"error": str(exc)}
    for host in hosts[:_MAX_TARGETS]:
        try:
            results["hosts"][host] = json.loads(await assets_tools.lookup_assets_by_hostname(host))
        except Exception as exc:  # noqa: BLE001
            results["hosts"][host] = {"error": str(exc)}
    return results


async def _check_iocs_for_ips(ips: list[str]) -> dict[str, Any]:
    checks: dict[str, Any] = {}
    lists_raw = await tabular_tools.search_table_lists(kind="correlationRule")
    lists_payload = json.loads(lists_raw)
    lists_body = lists_payload.get("body", lists_payload)
    items = lists_body if isinstance(lists_body, list) else []

    for ip in ips[:_MAX_TARGETS]:
        ip_checks: list[dict[str, Any]] = []
        for item in items[:5]:
            if not isinstance(item, dict):
                continue
            list_name = item.get("name")
            if not list_name:
                continue
            try:
                export_raw = await tabular_tools.export_table_list(
                    list_name,
                    where=f'"{ip}" in columns',
                    limit=10,
                )
                ip_checks.append({"list": list_name, "result": json.loads(export_raw)})
            except Exception as exc:  # noqa: BLE001
                ip_checks.append({"list": list_name, "error": str(exc)})
        checks[ip] = ip_checks
    return checks


async def investigate_incident(
    incident_id: str,
    events_limit: int = 20,
    include_raw_events: bool = True,
    include_ioc_checks: bool = False,
    include_target_assets: bool = False,
) -> str:
    """Собрать контекст для первичного расследования инцидента."""
    incident_raw, linked_raw = await asyncio.gather(
        incidents_tools.get_incident(incident_id),
        incidents_tools.list_incident_events(incident_id, limit=events_limit),
    )
    incident_payload = json.loads(incident_raw)
    incident_body = incident_payload.get("body", incident_payload)

    linked_payload = json.loads(linked_raw)

    time_from, time_to = _incident_time_window(
        incident_body if isinstance(incident_body, dict) else {}
    )

    recent_raw = await events_tools.list_events(
        limit=events_limit,
        offset=0,
        incident_id=incident_id,
        time_from=time_from,
        time_to=time_to,
    )
    recent_payload = json.loads(recent_raw)
    recent_body = recent_payload.get("body", recent_payload)
    if not include_raw_events and isinstance(recent_body, dict):
        recent_body = {
            "total": recent_body.get("totalItems") or recent_body.get("totalCount"),
            "truncated": True,
        }

    targets = incident_body.get("targets") if isinstance(incident_body, dict) else []
    targets_list = targets if isinstance(targets, list) else []

    result: dict[str, Any] = {
        "incident_id": incident_id,
        "summary": _build_summary(incident_body if isinstance(incident_body, dict) else {}),
        "incident": incident_body,
        "linked_events": linked_payload.get("body", linked_payload),
        "recent_events": recent_body,
        "time_window": {"from": time_from, "to": time_to},
    }

    if include_target_assets and targets_list:
        result["target_assets"] = await _lookup_target_assets(targets_list)

    if include_ioc_checks and targets_list:
        ips, _ = _extract_target_values(targets_list)
        if ips:
            result["ioc_checks"] = await _check_iocs_for_ips(ips)

    manifest = build_investigation_manifest(
        incident_body=incident_body if isinstance(incident_body, dict) else {},
        linked_body=linked_payload.get("body", linked_payload),
        recent_body=recent_body,
        include_raw_events=include_raw_events,
    )
    result["evidence_manifest"] = manifest.model_dump(mode="json")
    # Deprecated alias for older consumers; prefer evidence_manifest.
    result["data_quality"] = {
        "telemetry_level": manifest.telemetry_level,
        "max_confidence": manifest.max_confidence,
        "enrichment_limited": "siem_only",
    }

    return json.dumps(result, ensure_ascii=False, indent=2)
