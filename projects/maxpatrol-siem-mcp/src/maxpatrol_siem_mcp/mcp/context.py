from __future__ import annotations

from maxpatrol_siem_mcp.client.siem import SiemHttpClient

_client: SiemHttpClient | None = None


def set_siem_client(client: SiemHttpClient) -> None:
    global _client
    _client = client


def get_siem_client() -> SiemHttpClient:
    if _client is None:
        raise RuntimeError("SiemHttpClient is not initialized")
    return _client


def clear_siem_client() -> None:
    global _client
    _client = None
