from __future__ import annotations

from defectdojo_mcp.client.defectdojo import DefectDojoHttpClient
from defectdojo_mcp.config import Settings

_settings: Settings | None = None
_client: DefectDojoHttpClient | None = None


def set_runtime(*, settings: Settings, client: DefectDojoHttpClient) -> None:
    global _settings, _client
    _settings = settings
    _client = client


def get_settings() -> Settings:
    if _settings is None:
        raise RuntimeError("Settings is not initialized")
    return _settings


def get_defectdojo_client() -> DefectDojoHttpClient:
    if _client is None:
        raise RuntimeError("DefectDojoHttpClient is not initialized")
    return _client


def clear_runtime() -> None:
    global _settings, _client
    _settings = None
    _client = None
