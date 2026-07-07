from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import aiosqlite

from tenable_mcp.inventory.db import init_db


class CacheStore:
    """TTL API response cache backed by SQLite."""

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

    async def get(self, cache_key: str) -> dict[str, Any] | None:
        now = datetime.now(tz=UTC).isoformat()
        db = await self._connect()
        try:
            cursor = await db.execute(
                """
                SELECT payload_json FROM api_cache
                WHERE cache_key = ? AND expires_at > ?
                """,
                (cache_key, now),
            )
            row = await cursor.fetchone()
        finally:
            await db.close()
        if row is None:
            return None
        return json.loads(row["payload_json"])

    async def set(self, cache_key: str, payload: dict[str, Any], ttl_seconds: int) -> None:
        now = datetime.now(tz=UTC)
        expires = now + timedelta(seconds=ttl_seconds)
        db = await self._connect()
        try:
            await db.execute(
                """
                INSERT INTO api_cache (cache_key, fetched_at, expires_at, payload_json)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(cache_key) DO UPDATE SET
                    fetched_at=excluded.fetched_at,
                    expires_at=excluded.expires_at,
                    payload_json=excluded.payload_json
                """,
                (
                    cache_key,
                    now.isoformat(),
                    expires.isoformat(),
                    json.dumps(payload, ensure_ascii=False),
                ),
            )
            await db.commit()
        finally:
            await db.close()

    async def invalidate(self, cache_key: str) -> None:
        db = await self._connect()
        try:
            await db.execute("DELETE FROM api_cache WHERE cache_key = ?", (cache_key,))
            await db.commit()
        finally:
            await db.close()

    async def invalidate_prefix(self, prefix: str) -> None:
        db = await self._connect()
        try:
            await db.execute(
                "DELETE FROM api_cache WHERE cache_key LIKE ?",
                (f"{prefix}%",),
            )
            await db.commit()
        finally:
            await db.close()
