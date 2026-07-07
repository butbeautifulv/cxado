from __future__ import annotations

from pathlib import Path

import aiosqlite

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS assets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname TEXT NOT NULL DEFAULT '',
    fqdn TEXT,
    ip TEXT NOT NULL,
    mac TEXT,
    nessus_host_id INTEGER,
    os_name TEXT,
    os_version TEXT,
    os_build TEXT,
    os_arch TEXT,
    internet_facing INTEGER,
    last_scan_id INTEGER,
    last_history_id INTEGER,
    last_scan_at TEXT,
    critical_count INTEGER NOT NULL DEFAULT 0,
    high_count INTEGER NOT NULL DEFAULT 0,
    medium_count INTEGER NOT NULL DEFAULT 0,
    low_count INTEGER NOT NULL DEFAULT 0,
    info_count INTEGER NOT NULL DEFAULT 0,
    max_cvss REAL,
    raw_host_json TEXT,
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(ip, hostname)
);

CREATE INDEX IF NOT EXISTS idx_assets_ip ON assets(ip);
CREATE INDEX IF NOT EXISTS idx_assets_hostname ON assets(hostname);
CREATE INDEX IF NOT EXISTS idx_assets_last_scan ON assets(last_scan_id, last_history_id);

CREATE TABLE IF NOT EXISTS findings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_ip TEXT NOT NULL,
    plugin_id INTEGER NOT NULL,
    plugin_name TEXT NOT NULL,
    severity INTEGER NOT NULL DEFAULT 0,
    cvss REAL,
    port INTEGER NOT NULL DEFAULT -1,
    protocol TEXT NOT NULL DEFAULT '',
    state TEXT,
    first_seen TEXT,
    last_seen TEXT,
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(asset_ip, plugin_id, port, protocol)
);

CREATE INDEX IF NOT EXISTS idx_findings_asset_ip ON findings(asset_ip);
CREATE INDEX IF NOT EXISTS idx_findings_severity ON findings(severity);

CREATE TABLE IF NOT EXISTS scan_snapshots (
    scan_id INTEGER NOT NULL,
    history_key INTEGER NOT NULL DEFAULT -1,
    history_id INTEGER,
    status TEXT NOT NULL DEFAULT 'synced',
    exported_at TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    file_path TEXT,
    PRIMARY KEY (scan_id, history_key)
);

CREATE TABLE IF NOT EXISTS api_cache (
    cache_key TEXT PRIMARY KEY,
    fetched_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    payload_json TEXT NOT NULL
);
"""


def history_key(history_id: int | None) -> int:
    return history_id if history_id is not None else -1


async def init_db(db_path: str) -> None:
    path = Path(db_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    async with aiosqlite.connect(path) as db:
        await db.executescript(SCHEMA_SQL)
        await db.commit()
