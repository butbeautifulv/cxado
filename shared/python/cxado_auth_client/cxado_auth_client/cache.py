from __future__ import annotations

import time
from typing import Hashable


class TTLCache:
    def __init__(self) -> None:
        self._items: dict[Hashable, tuple[str, float]] = {}

    def get(self, key: Hashable) -> str | None:
        entry = self._items.get(key)
        if entry is None:
            return None
        token, expires_at = entry
        if time.monotonic() >= expires_at:
            self._items.pop(key, None)
            return None
        return token

    def put(self, key: Hashable, token: str, ttl_sec: int) -> None:
        self._items[key] = (token, time.monotonic() + ttl_sec)
