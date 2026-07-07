from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import aiosqlite

from tenable_mcp.inventory.db import history_key, init_db
from tenable_mcp.inventory.models import AssetRecord, FindingRecord, ScanSnapshot


def _dt_to_str(value: datetime | None) -> str | None:
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=UTC)
    return value.isoformat()


def _row_to_asset(row: aiosqlite.Row) -> dict[str, Any]:
    return dict(row)


class InventoryRepository:
    """SQLite-backed security inventory (mini-CMDB)."""

    def __init__(self, db_path: str) -> None:
        self._db_path = db_path
        self._initialized = False

    async def ensure_initialized(self) -> None:
        if not self._initialized:
            await init_db(self._db_path)
            self._initialized = True

    async def _connect(self) -> aiosqlite.Connection:
        await self.ensure_initialized()
        path = Path(self._db_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        db = await aiosqlite.connect(path)
        db.row_factory = aiosqlite.Row
        return db

    async def upsert_assets(self, assets: list[AssetRecord]) -> int:
        count = 0
        db = await self._connect()
        try:
            for asset in assets:
                await db.execute(
                    """
                    INSERT INTO assets (
                        hostname, fqdn, ip, mac, nessus_host_id,
                        os_name, os_version, os_build, os_arch, internet_facing,
                        last_scan_id, last_history_id, last_scan_at,
                        critical_count, high_count, medium_count, low_count, info_count,
                        max_cvss, raw_host_json, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(ip, hostname) DO UPDATE SET
                        fqdn=excluded.fqdn,
                        mac=COALESCE(excluded.mac, assets.mac),
                        nessus_host_id=COALESCE(excluded.nessus_host_id, assets.nessus_host_id),
                        os_name=COALESCE(excluded.os_name, assets.os_name),
                        os_version=COALESCE(excluded.os_version, assets.os_version),
                        os_build=COALESCE(excluded.os_build, assets.os_build),
                        os_arch=COALESCE(excluded.os_arch, assets.os_arch),
                        last_scan_id=excluded.last_scan_id,
                        last_history_id=excluded.last_history_id,
                        last_scan_at=excluded.last_scan_at,
                        critical_count=excluded.critical_count,
                        high_count=excluded.high_count,
                        medium_count=excluded.medium_count,
                        low_count=excluded.low_count,
                        info_count=excluded.info_count,
                        max_cvss=COALESCE(excluded.max_cvss, assets.max_cvss),
                        raw_host_json=excluded.raw_host_json,
                        updated_at=excluded.updated_at
                    """,
                    (
                        asset.hostname or "",
                        asset.fqdn,
                        asset.ip,
                        asset.mac,
                        asset.nessus_host_id,
                        asset.os_name,
                        asset.os_version,
                        asset.os_build,
                        asset.os_arch,
                        int(asset.internet_facing) if asset.internet_facing is not None else None,
                        asset.last_scan_id,
                        asset.last_history_id,
                        _dt_to_str(asset.last_scan_at),
                        asset.critical_count,
                        asset.high_count,
                        asset.medium_count,
                        asset.low_count,
                        asset.info_count,
                        asset.max_cvss,
                        asset.raw_host_json,
                        _dt_to_str(datetime.now(tz=UTC)),
                    ),
                )
                count += 1
            await db.commit()
        finally:
            await db.close()
        return count

    async def upsert_findings(self, findings: list[FindingRecord]) -> int:
        count = 0
        db = await self._connect()
        try:
            for finding in findings:
                await db.execute(
                    """
                    INSERT INTO findings (
                        asset_ip, plugin_id, plugin_name, severity, cvss,
                        port, protocol, state, first_seen, last_seen, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(asset_ip, plugin_id, port, protocol)
                    DO UPDATE SET
                        plugin_name=excluded.plugin_name,
                        severity=excluded.severity,
                        cvss=excluded.cvss,
                        state=excluded.state,
                        last_seen=excluded.last_seen,
                        updated_at=excluded.updated_at
                    """,
                    (
                        finding.asset_ip,
                        finding.plugin_id,
                        finding.plugin_name,
                        finding.severity,
                        finding.cvss,
                        finding.port if finding.port is not None else -1,
                        finding.protocol or "",
                        finding.state,
                        _dt_to_str(finding.first_seen),
                        _dt_to_str(finding.last_seen),
                        _dt_to_str(datetime.now(tz=UTC)),
                    ),
                )
                count += 1
            await db.commit()
        finally:
            await db.close()
        return count

    async def lookup_by_ip(self, ip: str) -> list[dict[str, Any]]:
        db = await self._connect()
        try:
            cursor = await db.execute(
                "SELECT * FROM assets WHERE ip = ? ORDER BY updated_at DESC",
                (ip,),
            )
            rows = await cursor.fetchall()
        finally:
            await db.close()
        return [_row_to_asset(row) for row in rows]

    async def lookup_by_hostname(self, hostname: str) -> list[dict[str, Any]]:
        db = await self._connect()
        try:
            cursor = await db.execute(
                """
                SELECT * FROM assets
                WHERE hostname = ? OR fqdn = ?
                ORDER BY updated_at DESC
                """,
                (hostname, hostname),
            )
            rows = await cursor.fetchall()
        finally:
            await db.close()
        return [_row_to_asset(row) for row in rows]

    async def search_inventory(
        self,
        *,
        ip_contains: str | None = None,
        os_contains: str | None = None,
        min_critical: int | None = None,
        min_high: int | None = None,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        clauses: list[str] = []
        params: list[Any] = []

        if ip_contains:
            clauses.append("ip LIKE ?")
            params.append(f"%{ip_contains}%")
        if os_contains:
            clauses.append("(os_name LIKE ? OR os_version LIKE ?)")
            params.extend([f"%{os_contains}%", f"%{os_contains}%"])
        if min_critical is not None:
            clauses.append("critical_count >= ?")
            params.append(min_critical)
        if min_high is not None:
            clauses.append("high_count >= ?")
            params.append(min_high)

        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        query = f"SELECT * FROM assets {where} ORDER BY critical_count DESC, high_count DESC LIMIT ?"
        params.append(limit)

        db = await self._connect()
        try:
            cursor = await db.execute(query, params)
            rows = await cursor.fetchall()
        finally:
            await db.close()
        return [_row_to_asset(row) for row in rows]

    async def get_vuln_summary(self, ip: str) -> dict[str, Any] | None:
        assets = await self.lookup_by_ip(ip)
        if not assets:
            return None
        asset = assets[0]
        return {
            "ip": asset["ip"],
            "hostname": asset.get("hostname"),
            "last_scan_id": asset.get("last_scan_id"),
            "last_history_id": asset.get("last_history_id"),
            "last_scan_at": asset.get("last_scan_at"),
            "critical_count": asset.get("critical_count", 0),
            "high_count": asset.get("high_count", 0),
            "medium_count": asset.get("medium_count", 0),
            "low_count": asset.get("low_count", 0),
            "info_count": asset.get("info_count", 0),
            "max_cvss": asset.get("max_cvss"),
        }

    async def save_snapshot(self, snapshot: ScanSnapshot) -> None:
        db = await self._connect()
        try:
            await db.execute(
                """
                INSERT INTO scan_snapshots (
                    scan_id, history_key, history_id, status, exported_at, content_hash, file_path
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(scan_id, history_key) DO UPDATE SET
                    status=excluded.status,
                    exported_at=excluded.exported_at,
                    content_hash=excluded.content_hash,
                    file_path=excluded.file_path
                """,
                (
                    snapshot.scan_id,
                    history_key(snapshot.history_id),
                    snapshot.history_id,
                    snapshot.status,
                    _dt_to_str(snapshot.exported_at),
                    snapshot.content_hash,
                    snapshot.file_path,
                ),
            )
            await db.commit()
        finally:
            await db.close()

    async def get_snapshot(self, scan_id: int, history_id: int | None) -> ScanSnapshot | None:
        db = await self._connect()
        try:
            cursor = await db.execute(
                """
                SELECT scan_id, history_id, status, exported_at, content_hash, file_path
                FROM scan_snapshots
                WHERE scan_id = ? AND history_key = ?
                """,
                (scan_id, history_key(history_id)),
            )
            row = await cursor.fetchone()
        finally:
            await db.close()
        if row is None:
            return None
        return ScanSnapshot(
            scan_id=row["scan_id"],
            history_id=row["history_id"],
            status=row["status"],
            exported_at=datetime.fromisoformat(row["exported_at"]),
            content_hash=row["content_hash"],
            file_path=row["file_path"],
        )

    async def count_assets_for_scan(self, scan_id: int, history_id: int | None) -> int:
        db = await self._connect()
        try:
            cursor = await db.execute(
                """
                SELECT COUNT(*) AS cnt FROM assets
                WHERE last_scan_id = ? AND COALESCE(last_history_id, -1) = ?
                """,
                (scan_id, history_key(history_id)),
            )
            row = await cursor.fetchone()
        finally:
            await db.close()
        return int(row["cnt"]) if row else 0

    async def get_findings_by_ip(
        self,
        ip: str,
        *,
        min_severity: int | None = None,
        limit: int = 100,
    ) -> list[dict[str, Any]]:
        clauses = ["asset_ip = ?"]
        params: list[Any] = [ip]
        if min_severity is not None:
            clauses.append("severity >= ?")
            params.append(min_severity)
        where = " AND ".join(clauses)
        query = (
            f"SELECT * FROM findings WHERE {where} "
            "ORDER BY severity DESC, cvss DESC LIMIT ?"
        )
        params.append(limit)

        db = await self._connect()
        try:
            cursor = await db.execute(query, params)
            rows = await cursor.fetchall()
        finally:
            await db.close()
        return [dict(row) for row in rows]
