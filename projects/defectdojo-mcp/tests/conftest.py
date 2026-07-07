import os

import pytest

os.environ.setdefault("DEFECTDOJO_BASE_URL", "http://defectdojo.test.local")
os.environ.setdefault("DEFECTDOJO_API_KEY", "test-token")

from defectdojo_mcp.config import Settings, get_settings


@pytest.fixture(autouse=True)
def _clear_settings_cache() -> None:
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


@pytest.fixture
def settings() -> Settings:
    return Settings(
        defectdojo_base_url="http://defectdojo.test.local",
        defectdojo_api_key="test-token",
        defectdojo_verify_ssl=False,
        defectdojo_readonly=False,
    )
