from __future__ import annotations

import hashlib
import json
from datetime import UTC, datetime
from typing import Any

import defusedxml.ElementTree as ET

from tenable_mcp.inventory.models import AssetRecord, FindingRecord


def _parse_dt(value: str | int | float | None) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value, tz=UTC)
    text = str(value).strip()
    if not text:
        return None
    if text.isdigit():
        return datetime.fromtimestamp(int(text), tz=UTC)
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None


def _severity_name(severity: int) -> str:
    return {0: "info", 1: "low", 2: "medium", 3: "high", 4: "critical"}.get(severity, "info")


def parse_scan_json_hosts(
    scan_data: dict[str, Any],
    *,
    scan_id: int,
    history_id: int | None,
) -> tuple[list[AssetRecord], list[FindingRecord]]:
    assets: list[AssetRecord] = []
    findings: list[FindingRecord] = []
    info = scan_data.get("info") or {}
    scan_end = _parse_dt(info.get("scan_end") or info.get("timestamp"))

    for host in scan_data.get("hosts") or []:
        hostname = host.get("hostname") or host.get("host_name")
        ip = host.get("ip") or host.get("hostname") or hostname
        if not ip:
            continue
        asset = AssetRecord(
            hostname=hostname,
            fqdn=hostname if hostname and "." in hostname else None,
            ip=str(ip),
            nessus_host_id=host.get("host_id"),
            last_scan_id=scan_id,
            last_history_id=history_id,
            last_scan_at=scan_end,
            critical_count=int(host.get("critical") or 0),
            high_count=int(host.get("high") or 0),
            medium_count=int(host.get("medium") or 0),
            low_count=int(host.get("low") or 0),
            info_count=int(host.get("info") or 0),
            raw_host_json=json.dumps(host, ensure_ascii=False),
        )
        assets.append(asset)

    return assets, findings


def parse_nessus_xml(
    content: bytes,
    *,
    scan_id: int,
    history_id: int | None,
) -> tuple[list[AssetRecord], list[FindingRecord]]:
    root = ET.fromstring(content)
    assets_by_ip: dict[str, AssetRecord] = {}
    findings: list[FindingRecord] = []
    now = datetime.now(tz=UTC)

    for report in root.findall(".//Report"):
        for host_el in report.findall("ReportHost"):
            host_name = host_el.get("name", "unknown")
            ip = host_name
            hostname = host_name
            os_name = None
            os_version = None
            mac = None
            severity_counts = {"critical": 0, "high": 0, "medium": 0, "low": 0, "info": 0}
            max_cvss: float | None = None

            for tag in host_el.findall("HostProperties/tag"):
                name = tag.get("name", "")
                value = tag.text or ""
                if name == "operating-system":
                    os_name = value
                elif name == "mac-address":
                    mac = value
                elif name == "host-ip":
                    ip = value or ip
                elif name == "host-fqdn":
                    hostname = value or hostname

            for item in host_el.findall("ReportItem"):
                severity = int(item.get("severity", "0"))
                severity_key = _severity_name(severity)
                if severity_key in severity_counts:
                    severity_counts[severity_key] += 1
                cvss_raw = item.get("cvss_base_score") or item.get("cvss3_base_score")
                cvss = float(cvss_raw) if cvss_raw else None
                if cvss is not None:
                    max_cvss = cvss if max_cvss is None else max(max_cvss, cvss)

                findings.append(
                    FindingRecord(
                        asset_ip=ip,
                        plugin_id=int(item.get("pluginID", "0")),
                        plugin_name=item.get("pluginName", "unknown"),
                        severity=severity,
                        cvss=cvss,
                        port=int(item.get("port")) if item.get("port") else None,
                        protocol=item.get("protocol"),
                        state=item.get("plugin_state"),
                        first_seen=now,
                        last_seen=now,
                    )
                )

            asset = AssetRecord(
                hostname=hostname,
                fqdn=hostname if "." in hostname else None,
                ip=ip,
                mac=mac,
                os_name=os_name,
                os_version=os_version,
                last_scan_id=scan_id,
                last_history_id=history_id,
                last_scan_at=now,
                critical_count=severity_counts["critical"],
                high_count=severity_counts["high"],
                medium_count=severity_counts["medium"],
                low_count=severity_counts["low"],
                info_count=severity_counts["info"],
                max_cvss=max_cvss,
                raw_host_json=json.dumps({"hostname": hostname, "ip": ip}, ensure_ascii=False),
            )
            assets_by_ip[ip] = asset

    return list(assets_by_ip.values()), findings


def content_hash(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()
