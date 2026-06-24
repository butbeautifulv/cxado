from __future__ import annotations

import httpx
import pytest

from cxado_auth_client import AuthBrokerClient


def test_get_access_token(httpx_mock: pytest.HttpMock) -> None:
    httpx_mock.add_response(
        method="POST",
        url="http://broker/v1/token",
        json={"access_token": "tok", "expires_in": 300, "token_type": "Bearer"},
    )
    client = AuthBrokerClient(
        base_url="http://broker",
        service_token="secret",
        service_id="egregore",
    )
    assert client.get_access_token("veil-api") == "tok"
    assert client.get_access_token("veil-api") == "tok"
    assert len(httpx_mock.get_requests()) == 1
