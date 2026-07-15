# Nexus: npm-proxy + go-proxy — handoff for setup

## Why

Build-контур egregore/veil (P30 Kaniko → Nexus) уже проксирует через Nexus:

- Docker base images (`nexus.svo.aero:8345` hub-proxy, `:8374` group-proxy)
- PyPI (`nexus.svo.aero:8443/repository/srsips-pypi/simple`, юзается `uv sync`)

Два места идут в обход Nexus, напрямую в паблик-интернет из Kaniko-пода на P30:

- **`bun install`** при сборке `egregore-ui` → `registry.npmjs.org`
- **`go build`** при сборке `veil-api`/`veil-mcp` → `proxy.golang.org`

Это уже задокументированная боль (`projects/veil/docs/architecture/threatintel-runtime.md` — обрывы/EOF при скачивании Go-модулей). Нужно завести те же прокси-репы в Nexus, что и для PyPI, чтобы всё шло по одной схеме.

Код (Dockerfile.corp, kaniko job-манифесты, build-скрипты) **уже обновлён** и ждёт эти два репозитория. Как только они появятся в Nexus — сборка сама начнёт их использовать, ничего больше менять не надо.

## Что завести в Nexus

### 1. `npm-proxy` (формат npm, тип proxy)

| Поле | Значение |
|---|---|
| Name | `npm-proxy` |
| Remote storage URL | `https://registry.npmjs.org` |
| Blob store | `default` |
| Content Max Age | 1440 (min) |
| Metadata Max Age | 1440 (min) |
| Negative cache | enabled, TTL 1440 |
| Auto blocking | enabled |

### 2. `go-proxy` (формат go, тип proxy)

| Поле | Значение |
|---|---|
| Name | `go-proxy` |
| Remote storage URL | `https://proxy.golang.org` |
| Blob store | `default` |
| Остальное | как у npm-proxy |

Оба формата нативные для Nexus Repository **OSS 3.20+** (на P30 стоит `OSS 3.70.1-02` — подтверждено `curl .../service/rest/v1/status` → `200`), доп. лицензий/плагинов не требуется.

Если создавать через **Nexus Web UI**: Administration → Repository → Repositories → Create repository → `npm (proxy)` / `go (proxy)` → заполнить поля выше → Create.

## Сеть / файрвол

- Эти два репо — **proxy**-типа: интернет туда нужен **самому Nexus** (исходящий HTTPS 443 на `registry.npmjs.org` и `proxy.golang.org`), а не P30/кластеру. Если у Nexus egress уже открыт для Docker Hub/PyPI-прокси (он явно открыт — это уже работает), то отдельной новой "дыры" наружу может не требоваться — просто два новых repo-пути на уже разрешённом хосте.
- Со стороны P30/Kaniko новых дыр не нужно — трафик идёт туда же, куда уже идёт PyPI: `nexus.svo.aero:8443`.

## Побочная находка (FYI, не блокирует)

Admin REST API Nexus (`/service/rest/v1/repositories`, `/service/rest/v1/repositories/cxado-docker`) отдаёт **404** с обоих SSH-хопов (`bbv-p30-wifi` и corp-NAT `bbv-p30-k44`) с кредами `admin-SEC` из `deploy/.secrets/cxado-k3s.env` — это на **уже существующем** репозитории `cxado-docker`, не только на новых. Похоже, `cxado-docker` заводился раньше вручную через UI, а не через `scripts/k8s/nexus-cxado-docker-setup.sh` (тот скрипт вызывает именно этот REST-эндпоинт и, получается, ни разу не проверялся вживую). Стоит на досуге понять: либо API-путь для repository-management отключён/задизейблен в конфиге Nexus, либо у `admin-SEC` не хватает `nx-repository-admin-*` привилегии. Если так — `nexus-cxado-docker-setup.sh` и написанный мной по его образцу `scripts/k8s/nexus-npm-go-proxy-setup.sh` тоже не смогут создавать репы автоматически, и заводить их придётся вручную через UI (как выше).

## Проверка после создания

```bash
./scripts/k8s/nexus-bootstrap-verify.sh
```

(шаг 00.9 в скрипте проверяет оба репо; если admin API по-прежнему 404 — этот шаг тоже может ложно фейлиться, тогда достаточно проверить вручную, что сборка `cxado-nexus-deploy.sh --build` для egregore-ui / veil проходит без обращений к npmjs.org/proxy.golang.org напрямую).

## Уже готово в репозитории (ничего трогать не надо)

- `deploy/registry.defaults.env` — `NEXUS_NPM_HOST/REPO`, `NEXUS_GO_HOST/REPO` (порт 8443, как у PyPI)
- `scripts/k8s/nexus-npm-go-proxy-setup.sh` — API-based create (может не сработать из-за 404 выше — тогда просто справочный список полей для UI)
- `projects/egregore/web_ui/Dockerfile.corp` — `bun install` через `BUN_CONFIG_REGISTRY` → `npm-proxy`
- `projects/veil/deploy/knowledge/docker/{api,mcp}.Dockerfile.corp` — `go build` через `GOPROXY` → `go-proxy`
- `deploy/k8s/kaniko/21-job-egregore-ui.yaml`, `22-job-veil-api.yaml`, `23-job-veil-mcp.yaml` — новые `--build-arg`
- `docs/deploy/nexus-egregore-loop.md`, `docs/deploy/nexus-veil-loop.md` — обновлённые prerequisite-шаги и troubleshooting
