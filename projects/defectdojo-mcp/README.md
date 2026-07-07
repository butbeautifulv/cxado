# defectdojo-mcp

MCP-сервер для DefectDojo API v2 (FastAPI + FastMCP) — triage уязвимостей из CI/CD пайплайнов.

## Документация API

Справка: [`docs/API.md`](docs/API.md)  
Источник: [DefectDojo API v2](https://demo.defectdojo.org/api/v2/oa3/swagger-ui/)

## Быстрый старт

```bash
cd projects/defectdojo-mcp
uv sync --all-groups
cp .env.example .env   # заполните DEFECTDOJO_* переменные
uv run defectdojo-mcp serve
```

- Health: `GET http://localhost:8096/health`
- MCP (streamable HTTP): `http://localhost:8096/mcp`

Или из корня монорепо:

```bash
make cxado-up-defectdojo-mcp
make cxado-smoke-defectdojo-mcp
```

## Cursor (stdio)

```json
{
  "mcpServers": {
    "defectdojo": {
      "command": "uv",
      "args": [
        "--directory",
        "/absolute/path/to/cys_framework/projects/defectdojo-mcp",
        "run",
        "defectdojo-mcp",
        "stdio"
      ],
      "env": {
        "DEFECTDOJO_BASE_URL": "http://localhost:8080",
        "DEFECTDOJO_API_KEY": "...",
        "DEFECTDOJO_VERIFY_SSL": "false",
        "DEFECTDOJO_READONLY": "false"
      }
    }
  }
}
```

## Readonly mode

`DEFECTDOJO_READONLY=true` блокирует мутирующие вызовы (POST/PUT/PATCH/DELETE).  
По умолчанию `false` — полный write для triage и import.

## MCP tools

### Findings (triage)

| Tool | Описание |
|------|----------|
| `list_findings` | Очередь findings (severity, active, product, test) |
| `get_finding` | Детали finding |
| `update_finding` | PATCH полей |
| `close_finding` | Закрыть |
| `verify_finding` | Verify |
| `add_finding_note` | Комментарий triage |
| `list_finding_notes` | История notes |
| `accept_finding_risks` | Bulk risk acceptance |
| `triage_finding` | Composite: finding + notes + test + product |

### Products / Engagements / Tests

| Tool | Описание |
|------|----------|
| `list_products` / `get_product` / `create_product` | Продукты |
| `list_engagements` / `get_engagement` / `create_engagement` | Engagements |
| `close_engagement` | Закрыть engagement |
| `list_tests` / `get_test` / `create_test` | Scanner runs |

### Import (CI/CD)

| Tool | Описание |
|------|----------|
| `import_scan` | Import scanner report (multipart, file_path or file_base64) |
| `reimport_scan` | Re-import в существующий test |
| `preview_import_scan` | Dry-run preview |

### Escape hatch

| Tool | Описание |
|------|----------|
| `defectdojo_request` | Универсальный HTTP |
| `search_api_docs` | Поиск по `docs/API.md` |

## Workflow (CI/CD triage)

1. `list_products` → `product_id`
2. `list_engagements` / `create_engagement` → `engagement_id`
3. `import_scan(scan_type="Semgrep JSON Report", file_path=...)` → `test_id`
4. `list_findings(product=..., severity=High, active=true)`
5. `triage_finding(id)` → контекст
6. `update_finding` / `add_finding_note` / `verify_finding` / `accept_finding_risks`

## Health

`GET /health` — liveness.

`GET /health?probe_defectdojo=true` — readiness: проверяет `GET /api/v2/users/?limit=1`.

## k3s deploy

```bash
cp deploy/.secrets/defectdojo-mcp.env.example deploy/.secrets/defectdojo-mcp.env
# заполните DEFECTDOJO_* credentials
./scripts/k8s/k3s-deploy-defectdojo-mcp.sh
```

- Helm chart: `deploy/helm/defectdojo-mcp/`
- In-cluster MCP: `http://defectdojo-mcp.cxado-app.svc.cluster.local:8096/mcp`

## Переменные окружения

См. [`.env.example`](.env.example).

## Тесты

```bash
uv run pytest -q
```

## Smoke

```bash
./scripts/smoke_mcp.sh
# или
DEFECTDOJO_MCP_URL=http://localhost:8096 ./scripts/smoke_mcp.sh
```
