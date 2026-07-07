from maxpatrol_siem_mcp.config import Settings, get_settings


def test_normalize_bare_host_base_url() -> None:
    settings = Settings(
        siem_base_url="10.20.16.130",
        siem_client_secret="secret",
        siem_username="user",
        siem_password="pass",
    )
    assert settings.siem_base_url_str == "https://10.20.16.130"


def test_default_mcp_port(monkeypatch) -> None:
    monkeypatch.delenv("MCP_PORT", raising=False)
    settings = Settings(
        siem_base_url="https://siem.test.local",
        siem_client_secret="secret",
        siem_username="user",
        siem_password="pass",
    )
    assert settings.mcp_port == 8094


def test_get_settings_uses_env(monkeypatch) -> None:
    get_settings.cache_clear()
    monkeypatch.setenv("SIEM_BASE_URL", "192.168.1.1")
    monkeypatch.setenv("SIEM_CLIENT_SECRET", "s")
    monkeypatch.setenv("SIEM_USERNAME", "u")
    monkeypatch.setenv("SIEM_PASSWORD", "p")
    settings = get_settings()
    assert settings.siem_base_url_str == "https://192.168.1.1"
    get_settings.cache_clear()
