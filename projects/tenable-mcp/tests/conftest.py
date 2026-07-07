import os

import pytest

os.environ.setdefault("NESSUS_BASE_URL", "https://nessus.test.local:8834")
os.environ.setdefault("NESSUS_USERNAME", "admin")
os.environ.setdefault("NESSUS_PASSWORD", "pass")
os.environ.setdefault("NESSUS_DB_PATH", ":memory:")

from tenable_mcp.config import Settings, get_settings


@pytest.fixture(autouse=True)
def _clear_settings_cache() -> None:
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


@pytest.fixture
def settings(tmp_path) -> Settings:
    return Settings(
        nessus_base_url="https://nessus.test.local:8834",
        nessus_username="admin",
        nessus_password="pass",
        nessus_verify_ssl=False,
        nessus_readonly=False,
        nessus_db_path=str(tmp_path / "test.db"),
        nessus_cache_ttl_seconds=300,
        nessus_export_ttl_seconds=3600,
    )
