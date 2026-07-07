import os

import pytest

# Set before importing application modules that read Settings at import time.
os.environ.setdefault("SIEM_BASE_URL", "https://siem.test.local")
os.environ.setdefault("SIEM_CLIENT_SECRET", "test-secret")
os.environ.setdefault("SIEM_USERNAME", "admin")
os.environ.setdefault("SIEM_PASSWORD", "pass")

from maxpatrol_siem_mcp.config import Settings, get_settings


@pytest.fixture(autouse=True)
def _clear_settings_cache() -> None:
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


@pytest.fixture
def settings() -> Settings:
    return Settings(
        siem_base_url="https://siem.test.local",
        siem_client_secret="test-secret",
        siem_username="admin",
        siem_password="pass",
        siem_verify_ssl=False,
    )
