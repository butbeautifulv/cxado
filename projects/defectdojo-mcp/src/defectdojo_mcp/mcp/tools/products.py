from __future__ import annotations

from typing import Any

from defectdojo_mcp.mcp.context import get_defectdojo_client


def _params(**kwargs: Any) -> dict[str, Any]:
    return {k: v for k, v in kwargs.items() if v is not None}


async def list_products(
    *,
    name: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string(
        "GET",
        "/api/v2/products/",
        params=_params(name=name, limit=limit, offset=offset),
    )


async def get_product(product_id: int) -> str:
    client = get_defectdojo_client()
    return await client.request_json_string("GET", f"/api/v2/products/{product_id}/")


async def create_product(name: str, description: str = "", prod_type: int | None = None) -> str:
    client = get_defectdojo_client()
    body: dict[str, Any] = {"name": name, "description": description}
    if prod_type is not None:
        body["prod_type"] = prod_type
    return await client.request_json_string("POST", "/api/v2/products/", json_body=body)
