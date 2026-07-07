from __future__ import annotations

from tenable_mcp.cache.store import CacheStore
from tenable_mcp.client.nessus import NessusHttpClient
from tenable_mcp.config import Settings
from tenable_mcp.inventory.repository import InventoryRepository

_settings: Settings | None = None
_client: NessusHttpClient | None = None
_inventory: InventoryRepository | None = None
_cache: CacheStore | None = None


def set_runtime(
    *,
    settings: Settings,
    client: NessusHttpClient,
    inventory: InventoryRepository,
    cache: CacheStore,
) -> None:
    global _settings, _client, _inventory, _cache
    _settings = settings
    _client = client
    _inventory = inventory
    _cache = cache


def get_settings() -> Settings:
    if _settings is None:
        raise RuntimeError("Settings is not initialized")
    return _settings


def get_nessus_client() -> NessusHttpClient:
    if _client is None:
        raise RuntimeError("NessusHttpClient is not initialized")
    return _client


def get_inventory() -> InventoryRepository:
    if _inventory is None:
        raise RuntimeError("InventoryRepository is not initialized")
    return _inventory


def get_cache() -> CacheStore:
    if _cache is None:
        raise RuntimeError("CacheStore is not initialized")
    return _cache


def clear_runtime() -> None:
    global _settings, _client, _inventory, _cache
    _settings = None
    _client = None
    _inventory = None
    _cache = None
