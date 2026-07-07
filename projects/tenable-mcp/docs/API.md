# Nessus Local REST API (MVP reference)

Source: [Nessus API docs](https://docs.tenable.com/nessus/api/)  
Default base URL: `https://<host>:8834`

## Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/session` | Login with `{"username","password"}` → `{"token"}` |
| DELETE | `/session` | Logout |

Authenticated requests use header: `X-Cookie: token=<token>`

## Scans

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/scans` | List scans |
| GET | `/scans/{id}` | Scan details + host summary |
| GET | `/scans/{id}/history` | Scan run history |
| POST | `/scans` | Create scan (`uuid` template + `settings`) |
| POST | `/scans/{id}/launch` | Launch scan |
| POST | `/scans/{id}/stop` | Stop scan |
| POST | `/scans/{id}/export` | Request export (`format`: nessus, csv, html, pdf) |
| GET | `/scans/{id}/export/{file_id}/status` | Poll export status |
| GET | `/scans/{id}/export/{file_id}/download` | Download export file |

## Templates

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/editor/scan/templates` | List scan templates (UUIDs for create) |

## Severity mapping

| Value | Label |
|-------|-------|
| 4 | Critical |
| 3 | High |
| 2 | Medium |
| 1 | Low |
| 0 | Informational |

## MCP workflow

1. `list_scans` — find scan_id
2. `wait_for_scan` or `get_scan_status` — wait for `completed`
3. `sync_scan_inventory(scan_id)` — export + parse + SQLite upsert
4. `lookup_asset_by_ip` / `search_inventory` / `list_high_risk_assets` — query local CMDB
5. `get_asset_findings(ip)` — plugin-level findings for one host

## MCP tools (agent surface)

| Tool | Description |
|------|-------------|
| `wait_for_scan` | Poll scan status until terminal state |
| `get_asset_findings` | Findings by IP from local SQLite |
| `list_high_risk_assets` | Hosts with critical/high severity |

## Health

`GET /health?probe_nessus=true` — readiness probe; calls Nessus `GET /scans`.

## Note on developer.tenable.com

[developer.tenable.com](https://developer.tenable.com/reference/navigate) documents **Tenable.io / Vulnerability Management** (`cloud.tenable.com`, `X-ApiKeys`).  
This MCP MVP targets **local Nessus** on port 8834.
