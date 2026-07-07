from __future__ import annotations

import json
from datetime import UTC, datetime

from tenable_mcp.inventory.models import ScanSnapshot, SyncResult
from tenable_mcp.inventory.nessus_parser import (
    content_hash,
    parse_nessus_xml,
    parse_scan_json_hosts,
)
from tenable_mcp.mcp.context import get_inventory, get_nessus_client, get_settings


async def sync_scan_inventory(
    scan_id: int,
    *,
    force_refresh: bool = False,
    export_format: str = "nessus",
) -> str:
    settings = get_settings()
    client = get_nessus_client()
    repo = get_inventory()

    history_id = await client.latest_history_id(scan_id)
    snapshot = await repo.get_snapshot(scan_id, history_id)

    if (
        not force_refresh
        and snapshot is not None
        and (datetime.now(tz=UTC) - snapshot.exported_at).total_seconds()
        < settings.nessus_export_ttl_seconds
    ):
        asset_count = await repo.count_assets_for_scan(scan_id, history_id)
        if asset_count > 0:
            result = SyncResult(
                scan_id=scan_id,
                history_id=history_id,
                assets_upserted=asset_count,
                from_cache=True,
                message="Skipped export; using existing snapshot and inventory rows",
            )
            return json.dumps(result.model_dump(), ensure_ascii=False, indent=2, default=str)

    scan_data = await client.get_scan(scan_id, history_id=history_id)
    json_assets, _ = parse_scan_json_hosts(scan_data, scan_id=scan_id, history_id=history_id)

    export_bytes = await client.export_scan(
        scan_id,
        export_format=export_format,
        history_id=history_id,
    )
    digest = content_hash(export_bytes)
    xml_assets, findings = parse_nessus_xml(
        export_bytes,
        scan_id=scan_id,
        history_id=history_id,
    )

    assets = xml_assets or json_assets
    assets_count = await repo.upsert_assets(assets)
    findings_count = await repo.upsert_findings(findings)

    await repo.save_snapshot(
        ScanSnapshot(
            scan_id=scan_id,
            history_id=history_id,
            status="synced",
            exported_at=datetime.now(tz=UTC),
            content_hash=digest,
        )
    )

    result = SyncResult(
        scan_id=scan_id,
        history_id=history_id,
        assets_upserted=assets_count,
        findings_upserted=findings_count,
        from_cache=False,
        message="Export parsed and inventory updated",
    )
    return json.dumps(result.model_dump(), ensure_ascii=False, indent=2, default=str)
