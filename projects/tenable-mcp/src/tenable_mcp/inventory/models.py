from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class AssetRecord(BaseModel):
    hostname: str | None = None
    fqdn: str | None = None
    ip: str
    mac: str | None = None
    nessus_host_id: int | None = None
    os_name: str | None = None
    os_version: str | None = None
    os_build: str | None = None
    os_arch: str | None = None
    internet_facing: bool | None = None
    last_scan_id: int | None = None
    last_history_id: int | None = None
    last_scan_at: datetime | None = None
    critical_count: int = 0
    high_count: int = 0
    medium_count: int = 0
    low_count: int = 0
    info_count: int = 0
    max_cvss: float | None = None
    raw_host_json: str | None = None


class FindingRecord(BaseModel):
    asset_ip: str
    plugin_id: int
    plugin_name: str
    severity: int
    cvss: float | None = None
    port: int | None = None
    protocol: str | None = None
    state: str | None = None
    first_seen: datetime | None = None
    last_seen: datetime | None = None


class ScanSnapshot(BaseModel):
    scan_id: int
    history_id: int | None = None
    status: str = "synced"
    exported_at: datetime
    content_hash: str
    file_path: str | None = None


class SyncResult(BaseModel):
    scan_id: int
    history_id: int | None = None
    assets_upserted: int = 0
    findings_upserted: int = 0
    from_cache: bool = False
    message: str = ""
