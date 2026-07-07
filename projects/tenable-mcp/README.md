# tenable-mcp

MCP-сервер для локального Nessus REST API (FastAPI + FastMCP) с мини-CMDB инвентаризации ИБ (SQLite).

## Документация API

Справка Nessus: [`docs/API.md`](docs/API.md)  
Источник: [Nessus REST API](https://docs.tenable.com/nessus/api/)

> **Важно:** [developer.tenable.com](https://developer.tenable.com/reference/navigate) описывает облачный Tenable.io API, а не локальный Nessus на `:8834`.

## Быстрый старт

```bash
cd projects/tenable-mcp
uv sync --all-groups
cp .env.example .env   # заполните NESSUS_* переменные
uv run tenable-mcp serve
```

- Health: `GET http://localhost:8095/health`
- MCP (streamable HTTP): `http://localhost:8095/mcp`

## Cursor (stdio)

```json
{
  "mcpServers": {
    "tenable-nessus": {
      "command": "uv",
      "args": [
        "--directory",
        "/absolute/path/to/cys_framework/projects/tenable-mcp",
        "run",
        "tenable-mcp",
        "stdio"
      ],
      "env": {
        "NESSUS_BASE_URL": "https://10.2.190.78:8834",
        "NESSUS_USERNAME": "admin",
        "NESSUS_PASSWORD": "...",
        "NESSUS_VERIFY_SSL": "false",
        "NESSUS_READONLY": "false",
        "NESSUS_DB_PATH": "./data/inventory.db"
      }
    }
  }
}
```

## Readonly mode

`NESSUS_READONLY=true` блокирует мутирующие вызовы (`create_scan`, `launch_scan`, `stop_scan`).  
Export и чтение (`list_scans`, `sync_scan_inventory`) разрешены.

## MCP tools

### Scans

| Tool | Описание |
|------|----------|
| `list_scans` | Список сканов |
| `get_scan` | Детали скана |
| `get_scan_status` | Статус скана |
| `wait_for_scan` | Poll до `completed`/`aborted` (timeout) |
| `list_scan_templates` | Шаблоны сканов |
| `create_scan` | Создать скан |
| `launch_scan` | Запустить скан |
| `stop_scan` | Остановить скан |

### Inventory (локальная SQLite CMDB)

| Tool | Описание |
|------|----------|
| `sync_scan_inventory` | Export → parse → upsert в инвентарь |
| `lookup_asset_by_ip` | Поиск по IP |
| `lookup_asset_by_hostname` | Поиск по hostname |
| `search_inventory` | Фильтр по IP/OS/severity |
| `get_asset_vuln_summary` | Агрегаты уязвимостей |
| `get_asset_findings` | Plugin-level findings по IP |
| `list_high_risk_assets` | Хосты с critical/high (min CVSS) |

### Escape hatch

| Tool | Описание |
|------|----------|
| `nessus_request` | Универсальный HTTP (с readonly guard) |
| `search_api_docs` | Поиск по `docs/API.md` |

## Workflow

1. `list_scans` → выбрать `scan_id`
2. `wait_for_scan(scan_id)` или `get_scan_status` → дождаться `completed`
3. `sync_scan_inventory(scan_id)` → заполнить локальную БД
4. `search_inventory` / `list_high_risk_assets` / `lookup_asset_by_ip` — без повторного export

Повторный `sync_scan_inventory` без `force_refresh=true` пропускает export, если snapshot для `history_id` ещё свежий.

## Health

`GET /health` — liveness (процесс жив).

`GET /health?probe_nessus=true` — readiness: дополнительно проверяет `GET /scans` на Nessus (`nessus_reachable`).

## k3s deploy

```bash
cp deploy/.secrets/tenable-mcp.env.example deploy/.secrets/tenable-mcp.env
# заполните NESSUS_* credentials
./scripts/k8s/k3s-deploy-tenable-mcp.sh
```

- Helm chart: `deploy/helm/tenable-mcp/`
- In-cluster MCP: `http://tenable-mcp.cxado-app.svc.cluster.local:8095/mcp`
- SQLite CMDB на PVC: `/data/inventory.db` (`NESSUS_DB_PATH`)
- egregore: см. [docs/integration/egregore-tenable-mcp.md](../../docs/integration/egregore-tenable-mcp.md)

Pod должен достучаться до Nessus API (например `https://10.2.190.78:8834`) с worker-ноды k3s.

## Переменные окружения

См. [`.env.example`](.env.example).

## Тесты

```bash
uv run pytest -q
```

## Smoke

```bash
./scripts/smoke_mcp.sh
```
