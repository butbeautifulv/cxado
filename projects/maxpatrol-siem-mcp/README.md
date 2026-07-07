# maxpatrol-siem-mcp

MCP-сервер для MaxPatrol 10 27.2 REST API (FastAPI + FastMCP).

## Документация API

Справка PT собрана в [`docs/API.md`](docs/API.md)  
Источник: [Виды запросов к API](https://help.ptsecurity.com/ru-RU/projects/mp10/27.2/help/2697416843)

## Быстрый старт

```bash
cd projects/maxpatrol-siem-mcp
uv sync --all-groups
cp .env.example .env   # заполните SIEM_* переменные
uv run maxpatrol-siem-mcp serve
```

- Health: `GET http://localhost:8094/health`
- MCP (streamable HTTP): `http://localhost:8094/mcp`

## Cursor (stdio)

```json
{
  "mcpServers": {
    "maxpatrol-siem": {
      "command": "uv",
      "args": [
        "--directory",
        "/absolute/path/to/cys_framework/projects/maxpatrol-siem-mcp",
        "run",
        "maxpatrol-siem-mcp",
        "stdio"
      ],
      "env": {
        "SIEM_BASE_URL": "https://siem.corp.local",
        "SIEM_CLIENT_SECRET": "...",
        "SIEM_USERNAME": "Administrator",
        "SIEM_PASSWORD": "...",
        "SIEM_VERIFY_SSL": "false",
        "SIEM_READONLY": "true"
      }
    }
  }
}
```

## Readonly mode

По умолчанию `SIEM_READONLY=true`. В этом режиме `SiemHttpClient` и `siem_request` блокируют мутирующие вызовы:

- **Разрешено:** `GET`, `HEAD`, `OPTIONS`
- **POST** только на whitelist:
  - `/api/v2/incidents` — список инцидентов
  - `/api/events/v2/events` — поиск событий
  - `/api/events/v2/events/aggregation` — агрегации
  - `/api/assets_temporal_readmodel/v1/assets_grid` — PDQL-токен
  - `/api/events/v1/table_lists/{name}/export` — экспорт IOC-списков
  - `/ptms/api/ual/v2/user_actions` — поиск в журнале действий
  - `/api/v1/uar/` — отчёты аудита
- **Запрещено:** `DELETE`, `PUT`, `PATCH` и любой POST вне whitelist

Для write-операций установите `SIEM_READONLY=false`.

## MCP tools

### Investigation

| Tool | Описание |
|------|----------|
| `investigate_incident` | Сводка: инцидент, события, summary; флаги `include_raw_events`, `include_target_assets`, `include_ioc_checks` |

### Context

| Tool | Описание |
|------|----------|
| `list_scopes` | Список инфраструктур |
| `get_incident_filters_hierarchy` | Дерево сохранённых фильтров инцидентов |

### Incidents

| Tool | Описание |
|------|----------|
| `list_incidents` | Список инцидентов |
| `get_incident` | Инцидент по ID (read model) |
| `list_incident_events` | Краткий список связанных событий |
| `get_incident_read_model_events` | События из read model (id + timestamp) |
| `get_incident_events` | Alias для `list_incident_events` |
| `get_incident_severities` | Справочник severity |
| `get_incident_types` | Справочник типов |

### Events

| Tool | Описание |
|------|----------|
| `list_events` | Список событий (defaults `timeFrom` / `filter.select`) |
| `search_events` | Поиск по PDQL `where` |
| `get_event_by_uuid` | Событие по UUID |
| `list_aggregated_events` | Агрегированные события для таймлайна |

### Assets

| Tool | Описание |
|------|----------|
| `get_asset_groups_hierarchy` | Дерево групп активов |
| `get_pdql_token` | PDQL → token |
| `get_asset_metadata` | Схема полей актива |
| `export_assets_grid` | CSV-экспорт по PDQL-токену |
| `lookup_assets_by_pdql` | Token + export в одном вызове |
| `lookup_assets_by_ip` | Поиск актива по IP |
| `lookup_assets_by_hostname` | Поиск актива по hostname |

### Tabular lists / IOC

| Tool | Описание |
|------|----------|
| `search_table_lists` | Поиск табличных списков |
| `get_table_list_info` | Метаданные списка |
| `export_table_list` | Экспорт записей (IOC lookup) |

### Audit (PT MC :3334)

| Tool | Описание |
|------|----------|
| `list_user_action_categories` | Категории действий пользователей |
| `list_user_actions` | Журнал действий |
| `search_user_actions` | Поиск по фильтру |

### Escape hatch

| Tool | Описание |
|------|----------|
| `siem_request` | Универсальный HTTP-запрос (с readonly guard) |
| `get_access_token` | OAuth token |
| `search_api_docs` | Поиск по `docs/API.md` |

## Workflow: расследование

1. `list_scopes` / `get_incident_filters_hierarchy` — навигация
2. `list_incidents` — фильтр `status=InProgress` или `New`
3. `investigate_incident(id, include_target_assets=true)` — стартовый контекст
4. `get_event_by_uuid` / `search_events` — углубление по событиям
5. `lookup_assets_by_ip` / `export_table_list` — активы и IOC
6. `search_user_actions` — кто менял инцидент вокруг времени события
7. `search_api_docs` — если endpoint неизвестен

## Переменные окружения

См. [`.env.example`](.env.example).

## Обновление справки API

```bash
uv run python scripts/scrape_api_docs.py
```

## Тесты

```bash
uv run pytest -q
```
