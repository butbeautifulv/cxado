import httpx
import pytest
import respx
from httpx import ASGITransport, AsyncClient

from tenable_mcp.app import create_app
from tenable_mcp.config import Settings


@pytest.mark.asyncio
@respx.mock
async def test_health_probe_nessus_success(settings) -> None:
    base = settings.nessus_base_url_str
    respx.post(f"{base}/session").mock(return_value=httpx.Response(200, json={"token": "t"}))
    respx.get(f"{base}/scans").mock(return_value=httpx.Response(200, json={"scans": []}))

    app = create_app(
        Settings(
            nessus_base_url=settings.nessus_base_url,
            nessus_username=settings.nessus_username,
            nessus_password=settings.nessus_password,
            nessus_verify_ssl=False,
            nessus_db_path=settings.nessus_db_path,
        )
    )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/health", params={"probe_nessus": "true"})
    assert response.status_code == 200
    body = response.json()
    assert body["nessus_reachable"] is True
