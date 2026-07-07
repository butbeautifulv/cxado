"""Evidence manifest builder for SIEM tool outputs (mirrors egregore domain/evidence contract)."""

from __future__ import annotations

import re
from typing import Any, Literal

from pydantic import BaseModel, Field

TelemetryLevel = Literal["rich", "sparse", "metadata_only"]

_FORENSIC_FIELD_PATHS: tuple[tuple[str, str], ...] = (
    ("subject.process.cmdline", "process"),
    ("object.process.cmdline", "process"),
    ("subject.process.name", "process"),
    ("object.process.name", "process"),
    ("subject.process.id", "pid"),
    ("object.process.id", "pid"),
    ("subject.account.name", "account"),
    ("object.account.name", "account"),
    ("object.name", "pipe"),
    ("object.value", "pipe"),
)

_KATA_TAA_MARKERS = ("kata_taa", "malicious_pipe_created", "hacktoolsdetection")


class FieldAvailability(BaseModel):
    field_path: str
    present: bool
    source: str = "incident"
    event_uuids: list[str] = Field(default_factory=list)


class Observation(BaseModel):
    obs_id: str
    kind: str
    value: str
    source_tool: str
    source_path: str
    event_uuid: str | None = None


class DataGap(BaseModel):
    field: str
    reason: str
    remediation: str = ""


class EvidenceManifest(BaseModel):
    telemetry_level: TelemetryLevel = "metadata_only"
    enrichment_sources: list[str] = Field(default_factory=lambda: ["siem"])
    required_external_sources: list[str] = Field(default_factory=list)
    observations: list[Observation] = Field(default_factory=list)
    field_availability: list[FieldAvailability] = Field(default_factory=list)
    data_gaps: list[DataGap] = Field(default_factory=list)
    max_confidence: float = 1.0


def _slug(value: str) -> str:
    cleaned = re.sub(r"[^\w.\-]+", "_", value.strip().lower())
    return cleaned[:80] or "unknown"


def _obs_id(kind: str, value: str, event_uuid: str | None = None) -> str:
    if event_uuid:
        return f"obs:evt:{event_uuid}:{kind}:{_slug(value)}"
    return f"obs:{kind}:{_slug(value)}"


def _get_nested(data: dict[str, Any], path: str) -> Any:
    current: Any = data
    for part in path.split("."):
        if not isinstance(current, dict):
            return None
        current = current.get(part)
    return current


def _walk_events(body: Any) -> list[dict[str, Any]]:
    if isinstance(body, list):
        return [item for item in body if isinstance(item, dict)]
    if not isinstance(body, dict):
        return []
    for key in ("events", "items", "data"):
        items = body.get(key)
        if isinstance(items, list):
            return [item for item in items if isinstance(item, dict)]
    return []


def _add_observation(
    observations: dict[str, Observation],
    *,
    kind: str,
    value: str,
    source_tool: str,
    source_path: str,
    event_uuid: str | None = None,
) -> None:
    text = str(value).strip()
    if not text:
        return
    oid = _obs_id(kind, text, event_uuid)
    if oid in observations:
        return
    observations[oid] = Observation(
        obs_id=oid,
        kind=kind,
        value=text,
        source_tool=source_tool,
        source_path=source_path,
        event_uuid=event_uuid,
    )


def _scan_event_fields(
    event: dict[str, Any],
    *,
    source_tool: str,
    source: str,
    observations: dict[str, Observation],
    availability: dict[str, FieldAvailability],
) -> None:
    event_uuid = str(event.get("uuid") or event.get("id") or "").strip() or None
    for field_path, kind in _FORENSIC_FIELD_PATHS:
        value = _get_nested(event, field_path)
        if value is None:
            continue
        text = str(value).strip()
        if not text:
            continue
        fa = availability.get(field_path)
        if fa is None:
            fa = FieldAvailability(field_path=field_path, present=False, source=source)
            availability[field_path] = fa
        fa.present = True
        if event_uuid and event_uuid not in fa.event_uuids:
            fa.event_uuids.append(event_uuid)
        _add_observation(
            observations,
            kind=kind,
            value=text,
            source_tool=source_tool,
            source_path=f"{source}.{event_uuid or 'event'}.{field_path}",
            event_uuid=event_uuid,
        )
    for host_key in ("event_src.host", "src.host", "dst.host"):
        host = _get_nested(event, host_key)
        if host:
            _add_observation(
                observations,
                kind="host",
                value=str(host),
                source_tool=source_tool,
                source_path=f"{source}.{event_uuid or 'event'}.{host_key}",
                event_uuid=event_uuid,
            )
    for ip_key in ("event_src.ip", "src.ip", "dst.ip"):
        ip = _get_nested(event, ip_key)
        if ip:
            _add_observation(
                observations,
                kind="ip",
                value=str(ip),
                source_tool=source_tool,
                source_path=f"{source}.{event_uuid or 'event'}.{ip_key}",
                event_uuid=event_uuid,
            )
    correlation = event.get("correlation_name")
    if correlation:
        _add_observation(
            observations,
            kind="correlation_rule",
            value=str(correlation),
            source_tool=source_tool,
            source_path=f"{source}.{event_uuid or 'event'}.correlation_name",
            event_uuid=event_uuid,
        )


def _incident_observations(
    incident_body: dict[str, Any],
    *,
    source_tool: str,
    observations: dict[str, Observation],
) -> list[str]:
    rules: list[str] = []
    for rule in incident_body.get("correlationRuleNames") or []:
        text = str(rule).strip()
        if not text:
            continue
        rules.append(text)
        _add_observation(
            observations,
            kind="correlation_rule",
            value=text,
            source_tool=source_tool,
            source_path="incident.correlationRuleNames",
        )
    if incident_body.get("key"):
        _add_observation(
            observations,
            kind="incident_key",
            value=str(incident_body["key"]),
            source_tool=source_tool,
            source_path="incident.key",
        )
    if incident_body.get("category"):
        _add_observation(
            observations,
            kind="category",
            value=str(incident_body["category"]),
            source_tool=source_tool,
            source_path="incident.category",
        )
    for idx, target in enumerate(incident_body.get("targets") or []):
        if not isinstance(target, dict):
            continue
        if target.get("name"):
            _add_observation(
                observations,
                kind="host",
                value=str(target["name"]),
                source_tool=source_tool,
                source_path=f"incident.targets[{idx}].name",
            )
        for addr in target.get("addresses") or []:
            if addr:
                _add_observation(
                    observations,
                    kind="ip",
                    value=str(addr),
                    source_tool=source_tool,
                    source_path=f"incident.targets[{idx}].addresses",
                )
    return rules


def _kata_taa_detected(rules: list[str], incident_body: dict[str, Any]) -> bool:
    corpus = " ".join(rules).lower()
    if any(marker in corpus for marker in _KATA_TAA_MARKERS):
        return True
    for field in ("category", "type", "name"):
        value = str(incident_body.get(field, "")).lower()
        if any(marker in value for marker in _KATA_TAA_MARKERS):
            return True
    return False


def build_investigation_manifest(
    *,
    incident_body: dict[str, Any],
    linked_body: Any,
    recent_body: Any,
    include_raw_events: bool,
    source_tool: str = "investigate_incident",
) -> EvidenceManifest:
    observations: dict[str, Observation] = {}
    availability: dict[str, FieldAvailability] = {}
    rules = _incident_observations(incident_body, source_tool=source_tool, observations=observations)
    for event in _walk_events(linked_body):
        _scan_event_fields(
            event,
            source_tool=source_tool,
            source="linked_events",
            observations=observations,
            availability=availability,
        )
    recent_truncated = isinstance(recent_body, dict) and bool(recent_body.get("truncated"))
    if include_raw_events:
        for event in _walk_events(recent_body):
            _scan_event_fields(
                event,
                source_tool=source_tool,
                source="recent_events",
                observations=observations,
                availability=availability,
            )

    has_cmdline = any(fa.present for fp, fa in availability.items() if "cmdline" in fp or "process.name" in fp)
    has_account = any(fa.present for fp, fa in availability.items() if "account" in fp)
    has_pipe = availability.get("object.name", FieldAvailability(field_path="object.name", present=False)).present
    kata_taa = _kata_taa_detected(rules, incident_body)

    data_gaps: list[DataGap] = []
    if not has_cmdline:
        data_gaps.append(
            DataGap(
                field="subject.process.cmdline",
                reason="not_in_siem" if include_raw_events else "not_selected",
                remediation="Request full event telemetry or check EDR/KATA console for process details.",
            )
        )
    if not has_account:
        data_gaps.append(
            DataGap(
                field="subject.account.name",
                reason="not_in_siem",
                remediation="Collect authentication audit logs or endpoint telemetry for account context.",
            )
        )
    if kata_taa and not has_pipe:
        data_gaps.append(
            DataGap(
                field="object.name",
                reason="vendor_api_unavailable",
                remediation="Open KATA console for pipe name and payload details (TAA API enrichment unavailable).",
            )
        )

    required_external: list[str] = []
    if kata_taa and (not has_cmdline or not has_pipe):
        required_external.append("kata_taa_console")

    if not observations:
        telemetry_level: TelemetryLevel = "metadata_only"
        max_confidence = 0.3
    elif kata_taa and not has_cmdline:
        telemetry_level = "sparse"
        max_confidence = 0.5
    elif not has_cmdline and not has_account:
        telemetry_level = "sparse"
        max_confidence = 0.5
    elif recent_truncated and not include_raw_events:
        telemetry_level = "sparse"
        max_confidence = 0.5
    else:
        telemetry_level = "rich"
        max_confidence = 1.0

    for fp, _ in _FORENSIC_FIELD_PATHS:
        if fp not in availability:
            availability[fp] = FieldAvailability(field_path=fp, present=False, source="incident")

    return EvidenceManifest(
        telemetry_level=telemetry_level,
        enrichment_sources=["siem"],
        required_external_sources=required_external,
        observations=list(observations.values()),
        field_availability=list(availability.values()),
        data_gaps=data_gaps,
        max_confidence=max_confidence,
    )
