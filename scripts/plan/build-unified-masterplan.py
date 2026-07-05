#!/usr/bin/env python3
"""Build docs/egregore_unified_masterplan.md from three source plans."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANS = ROOT / ".cursor" / "plans"
OUT = ROOT / "docs" / "egregore_unified_masterplan.md"

SOURCES = {
    "deploy": PLANS / "reliable_k3s_egregore_deploy_5ce71772.plan.md",
    "platform": PLANS / "egregore_platform_masterplan_97ac326c.plan.md",
    "datasources": PLANS / "egregore-datasources-rbac_d4df7472.plan.md",
}

QUEUE_TODOS = [
    ("unified-que-01-topic-constant", "kafka_topics.py: WORKER_JOBS_TOPIC = worker.jobs", "completed", "new", "que-01"),
    ("unified-que-02-enqueue-single", "kafka_queue.py: _topic_for_job always worker.jobs", "completed", "new", "que-02"),
    ("unified-que-03-consumer-single", "kafka_queue.py: subscribe single topic; drop _worker_job_topics", "completed", "new", "que-03"),
    ("unified-que-04-max-poll-test", "test_kafka_queue.py: single topic + max_poll_ms", "completed", "new", "que-04"),
    ("unified-que-05-k8s-topics-job", "15-redpanda-topics-job.yaml: worker.jobs -p 8; drop per-persona", "completed", "new", "que-05"),
    ("unified-que-06-migration-doc", "deploy_logs/kafka_migration_YYYYMMDD.md cutover steps", "completed", "new", "que-06"),
    ("unified-que-07-helm-deploy", "bundle + helm deploy queue-unify image tag", "pending", "new", "que-07"),
    ("unified-que-08-lag-gate", "gate: LAG=0 under 2 parallel POST", "pending", "new", "que-08"),
    ("unified-que-09-deprecate-persona-group", "kafka_queue.py: workers-{persona} CLI-only or remove", "completed", "new", "que-09"),
    ("unified-que-10-architecture-doc", "ARCHITECTURE.md: single queue diagram", "completed", "new", "que-10"),
]

CATALOG_TODOS = [
    ("unified-cat-01-inventory-hybrid", "doc: all load_hybrid_registry / AgentRegistry.load call sites", "completed", "new", "cat-01"),
    ("unified-cat-02-seed-api-audit", "verify POST /catalog/seed covers cybersec profile", "completed", "new", "cat-02"),
    ("unified-cat-03-bootstrap-script", "scripts: bootstrap calls API seed on deploy", "completed", "new", "cat-03"),
    ("unified-cat-04-remove-fs-merge", "hybrid_registry.py: DB-only when USE_DYNAMIC_CATALOG=true", "completed", "new", "cat-04"),
    ("unified-cat-05-fallback-dev-only", "FS load only USE_MEMORY_FALLBACK=true", "completed", "new", "cat-05"),
    ("unified-cat-06-reload-semantics", "reload_agent_registry without FS re-read", "completed", "new", "cat-06"),
    ("unified-cat-07-migrate-job", "helm init job calls bootstrap script", "pending", "new", "cat-07"),
    ("unified-cat-08-tests", "contract: prod never reads agents/personas/*.yaml at runtime", "completed", "new", "cat-08"),
    ("unified-cat-09-docs", "docs/CATALOG_SEED.md API-only policy", "completed", "new", "cat-09"),
]

PYTHON_REFACTOR_TODOS = [
    (
        "unified-py-01-async-boundary-inventory",
        "inventory all asyncio.run/create_task usage; classify CLI-only vs app-path and record allowed boundaries",
        "completed",
        "new",
        "py-01",
    ),
    (
        "unified-py-02-resource-lifecycle-contract",
        "define async Closeable/ManagedResource protocols for queue, bus, rate limiter, HTTP/Kafka clients",
        "completed",
        "new",
        "py-02",
    ),
    (
        "unified-py-03-kafka-queue-aclose",
        "KafkaJobQueue: add aclose() and stop producer/consumer deterministically; worker daemon calls it in finally",
        "completed",
        "new",
        "py-03",
    ),
    (
        "unified-py-04-kafka-fallback-policy",
        "KafkaJobQueue: replace silent broad fallback with typed unavailable/decode errors, structured logs, and fallback metrics",
        "completed",
        "new",
        "py-04",
    ),
    (
        "unified-py-05-kafka-publisher-port",
        "consolidate kafka_events/audit/control/paused one-shot producers behind one async publisher adapter",
        "completed",
        "new",
        "py-05",
    ),
    (
        "unified-py-06-sync-wrapper-guard",
        "make sync wrappers explicit CLI/test adapters; guard against asyncio.run inside running event loops",
        "completed",
        "new",
        "py-06",
    ),
    (
        "unified-py-07-fastapi-task-supervisor",
        "FastAPI lifespan: track refresh/planner background tasks in a supervisor with cancellation and exception logging",
        "completed",
        "new",
        "py-07",
    ),
    (
        "unified-py-08-planner-job-state",
        "manual async planner: persist planning/running/failed transitions instead of only logger.exception",
        "completed",
        "new",
        "py-08",
    ),
    (
        "unified-py-09-bus-dispatch-supervision",
        "RedisBusTransport: supervise async handlers, capture task exceptions, and provide pubsub/redis close path",
        "completed",
        "new",
        "py-09",
    ),
    (
        "unified-py-10-rate-limiter-lifecycle",
        "RedisRateLimiter: injectable async redis client + aclose(); log/metric fallback to memory limiter",
        "completed",
        "new",
        "py-10",
    ),
    (
        "unified-py-11-http-client-resilience",
        "centralize httpx client lifecycle/timeouts/retry policy for SIEM, MCP gateway, Veil and Veneno adapters",
        "completed",
        "new",
        "py-11",
    ),
    (
        "unified-py-12-settings-startup-validation",
        "Settings validators: enum-like fields, timeout ordering, USE_KAFKA bootstrap requirement, prod fallback guards",
        "completed",
        "new",
        "py-12",
    ),
    (
        "unified-py-13-secret-safe-settings",
        "Settings: protect secrets with SecretStr/safe repr and reject default passwords in prod",
        "completed",
        "new",
        "py-13",
    ),
    (
        "unified-py-14-typed-infrastructure-ports",
        "add Protocols for JobQueue, BusTransport, KafkaPublisher, RateLimiter without importing infrastructure into domain/application",
        "completed",
        "new",
        "py-14",
    ),
    (
        "unified-py-15-worker-payload-dtos",
        "replace hot-path dict[str, Any] job/result payloads with Pydantic boundary DTOs where payload shape is known",
        "completed",
        "new",
        "py-15",
    ),
    (
        "unified-py-16-error-hierarchy",
        "introduce typed infra/application errors and remove except/pass or except/return False on important paths",
        "completed",
        "new",
        "py-16",
    ),
    (
        "unified-py-17-correlation-propagation",
        "propagate correlation_id through API background planner, Kafka publishers, bus dispatch and worker logs",
        "completed",
        "new",
        "py-17",
    ),
    (
        "unified-py-18-fallback-metrics",
        "add Prometheus counters for Kafka/Redis/HTTP fallback, producer failures, dropped async handler exceptions",
        "completed",
        "new",
        "py-18",
    ),
    (
        "unified-py-19-timeout-cancellation-tests",
        "tests: worker timeout cleanup, queue aclose, planner background cancellation, Kafka fallback policy",
        "completed",
        "new",
        "py-19",
    ),
    (
        "unified-py-20-async-fixtures",
        "tests: reusable pytest async fixtures for FastAPI lifespan, Kafka queue, Redis limiter, httpx mock transports",
        "completed",
        "new",
        "py-20",
    ),
    (
        "unified-py-21-layer-boundary-contracts",
        "extend import-linter/contracts so domain/application stay independent while new ports live in application layer",
        "completed",
        "new",
        "py-21",
    ),
    (
        "unified-py-22-uv-workflow-checks",
        "document and gate uv workflow: uv lock/check, ruff, import-linter, pytest_batches for refactor PRs",
        "completed",
        "new",
        "py-22",
    ),
]

PLATFORM_STATUS_OVERRIDES: dict[str, str] = {
    "master-p0-01-inventory-runtime": "completed",
    "master-p0-02-inventory-orchestration": "completed",
    "master-p0-03-inventory-tools": "completed",
    "master-p0-04-inventory-memory": "completed",
    "master-p0-05-inventory-eval": "completed",
    "master-p0-06-inventory-policy": "completed",
    "master-p0-07-inventory-soc": "completed",
    "master-p0-08-trace-event-model": "completed",
    "master-p0-09-smoke-interactive": "completed",
    "master-p0-10-smoke-worker": "completed",
    "master-p0-11-stub-metric-spec": "completed",
    "master-p0-12-policy-fallback-metric-spec": "completed",
    "master-p1-01-product-pack-model": "completed",
    "master-p1-02-domain-pack-model": "completed",
    "master-p1-03-persona-pack-model": "completed",
    "master-p1-04-eval-pack-model": "completed",
    "master-p1-05-product-manifest-schema": "completed",
    "master-p1-06-seed-cybersec-product": "cancelled",
    "master-p1-07-seed-general-product": "completed",
    "master-p1-08-seed-gaia-product": "completed",
    "master-p1-09-default-profile-compat": "completed",
    "master-p1-10-policy-defaults-split": "completed",
    "master-p1-11-event-model-generic": "completed",
    "master-p1-12-event-adapter-security": "completed",
    "master-p1-13-routing-domain-adapter": "completed",
    "master-p1-14-tests-product-pack": "completed",
    "master-p2-01-run-kernel-port": "completed",
    "master-p2-02-trajectory-model": "completed",
    "master-p2-03-trace-model-call": "completed",
    "master-p2-04-trace-tool-call": "completed",
    "master-p2-05-trace-memory": "completed",
    "master-p2-06-trace-eval": "completed",
    "master-p2-07-kernel-state-map": "completed",
    "master-p2-08-kernel-budget": "completed",
    "master-p2-09-kernel-memory-hook": "completed",
    "master-p2-10-kernel-tool-hook": "completed",
    "master-p2-11-runstep-adapter": "completed",
    "master-p2-12-workerjob-adapter": "completed",
    "master-p2-13-kernel-tests": "completed",
    "master-p2-14-e2e-smoke-kernel": "completed",
    "master-p3-01-tool-provider-port": "completed",
    "master-p3-02-tool-status-model": "completed",
    "master-p3-03-tool-schema-exporter": "completed",
    "master-p3-04-tool-gateway-port": "completed",
    "master-p3-05-tools-discovery-module": "completed",
    "master-p3-06-tools-rag-module": "completed",
    "master-p3-07-tools-siem-module": "completed",
    "master-p3-11-tool-registry-compose": "completed",
    "master-p3-12-stub-result-contract": "completed",
    "master-p3-14-bfcl-schema-smoke": "completed",
    "master-p3-08-tools-sandbox-module": "completed",
    "master-p3-09-tools-web-module": "completed",
    "master-p3-10-tools-orchestration-module": "completed",
    "master-p3-13-tool-matrix-generated": "completed",
    "master-p4-01-sgr-tool-availability": "completed",
    "master-p4-02-sgr-allowlist-fix": "completed",
    "master-p4-03-sgr-hybrid-port": "completed",
    "master-p4-04-sgr-hybrid-service": "completed",
    "master-p4-05-sgr-hybrid-runtime-wire": "completed",
    "master-p4-06-sgr-hybrid-trace": "completed",
    "master-p4-07-sgr-iron-selector": "completed",
    "master-p4-08-sgr-iron-args": "completed",
    "master-p4-09-sgr-iron-policy": "completed",
    "master-p4-10-sgr-iron-runtime-wire": "completed",
    "master-p4-11-sgr-nextstep-deferred-doc": "completed",
    "master-p4-12-sgr-gaia-ab": "completed",
    "master-p4-13-sgr-bfcl-ab": "completed",
    "master-p4-14-sgr-tests": "completed",
}

DATASOURCE_STATUS_OVERRIDES: dict[str, str] = {
    "ds-a1-01-datasource-model": "completed",
    "ds-a1-02-datasource-capabilities": "completed",
    "ds-a1-03-datasource-acl-fields": "completed",
    "ds-a1-04-datasource-validation": "completed",
    "ds-a1-05-datasource-tests": "completed",
    "ds-a2-01-port": "completed",
    "ds-a2-02-inmemory-adapter": "completed",
    "ds-a2-03-catalog-adapter-skeleton": "completed",
    "ds-a2-04-registry-factory-hook": "completed",
    "ds-b1-01-authz-decision-dto": "completed",
    "ds-b1-02-authz-input-shape": "completed",
    "ds-b1-03-authz-contract-tests": "completed",
    "ds-b2-01-get-only-default-rule": "completed",
    "ds-b2-02-persona-to-roles": "completed",
    "ds-b2-03-classification-check": "completed",
    "ds-b2-04-allowlist-override": "completed",
    "ds-b2-05-matrix-tests": "completed",
    "ds-c1-01-tool-metadata": "completed",
    "ds-c1-02-attach-time-filter": "completed",
    "ds-c1-03-attach-time-tests": "completed",
    "ds-c2-01-exec-boundary-check": "completed",
    "ds-c2-02-error-shape": "completed",
    "ds-c2-03-exec-boundary-tests": "completed",
    "ds-c3-01-trace-policy-events": "completed",
    "ds-c3-02-trace-tool-events": "completed",
    "ds-c3-03-audit-storage-adapter": "completed",
    "ds-c3-04-audit-tests": "completed",
    "ds-d1-01-exporter-options": "completed",
    "ds-d1-02-model-family-knobs": "completed",
    "ds-d1-03-schema-export-tests": "completed",
    "ds-d2-01-schema-fetch": "completed",
    "ds-d2-02-args-validation": "completed",
    "ds-d2-03-schema-mismatch-error": "completed",
    "ds-d2-04-validation-tests": "completed",
}

DEPLOY_EXTRA = [
    (
        "unified-dep-kafka-max-poll",
        "deploy kafka_queue max_poll_interval_ms fix tag offline-20260703-kafkapoll",
        "pending",
        "new",
        "dep-kafka-max-poll",
    ),
]

# Local-first code/doc completions (k8s gates remain pending in source plan).
DEPLOY_STATUS_OVERRIDES: dict[str, str] = {
    "p8a-trace-path-matrix": "completed",
    "p8e-langfuse-forensic-extend": "completed",
}

PLATFORM_WAVES = {
    "master-p0-": ("D0", ""),
    "master-p1-": ("D1", "unified-cat-04"),
    "master-p2-": ("D2", "unified-que-03"),
    "master-p3-": ("D3", "unified-plat-master-p2-13-kernel-tests"),
    "master-p4-": ("D3", ""),
    "master-p5-": ("D3", ""),
    "master-p6-": ("D3", ""),
    "master-p7-": ("D3", ""),
    "master-p8-": ("D3", ""),
    "master-p9-": ("D3", ""),
    "master-p10-": ("D4", ""),
    "master-p11-": ("D4", ""),
}

DS_WAVES = {
    "ds-a": ("E0", ""),
    "ds-b": ("E0", ""),
    "ds-c": ("E1", "unified-plat-master-p2-10-kernel-tool-hook"),
    "ds-d": ("E1", ""),
    "ds-e": ("E2", ""),
    "ds-f": ("E2", ""),
    "ds-g": ("E2", ""),
}


def parse_todos(text: str) -> list[dict]:
    todos = []
    pattern = re.compile(
        r"  - id: (.+)\n    content: (.+)\n    status: (\w+)",
        re.MULTILINE,
    )
    for m in pattern.finditer(text):
        tid = m.group(1).strip()
        content = m.group(2).strip().strip('"')
        status = m.group(3).strip()
        todos.append({"id": tid, "content": content, "status": status})
    return todos


def _completed_prefix_overrides(text: str, prefixes: tuple[str, ...]) -> dict[str, str]:
    return {
        t["id"]: "completed"
        for t in parse_todos(text)
        if any(t["id"].startswith(p) for p in prefixes)
    }


def _apply_wave_overrides() -> None:
    platform_text = SOURCES["platform"].read_text()
    ds_text = SOURCES["datasources"].read_text()
    PLATFORM_STATUS_OVERRIDES.update(
        _completed_prefix_overrides(
            platform_text,
            (
                "master-p5-",
                "master-p6-",
                "master-p7-",
                "master-p8-",
                "master-p9-",
                "master-p10-",
                "master-p11-",
            ),
        )
    )
    DATASOURCE_STATUS_OVERRIDES.update(
        _completed_prefix_overrides(ds_text, ("ds-e", "ds-f", "ds-g"))
    )


_apply_wave_overrides()


def tags_for_platform(source_id: str) -> tuple[str, str]:
    for prefix, (wave, blocked) in PLATFORM_WAVES.items():
        if source_id.startswith(prefix):
            tags = f"[stream D][wave {wave}]"
            if blocked:
                tags += f"[blocked_by: {blocked}]"
            if source_id == "master-p0-10-smoke-worker":
                tags += "[blocked_by: unified-que-08-lag-gate]"
            if source_id == "master-p1-06-seed-cybersec-product":
                tags += "[superseded_by: unified-cat-03-bootstrap-script]"
            return wave, tags
    return "D3", "[stream D][wave D3]"


def tags_for_ds(source_id: str) -> tuple[str, str]:
    for prefix, (wave, blocked) in DS_WAVES.items():
        if source_id.startswith(prefix):
            tags = f"[stream E][wave {wave}]"
            if blocked:
                tags += f"[blocked_by: {blocked}]"
            if source_id in {"ds-c3-01-trace-policy-events", "ds-c3-02-trace-tool-events"}:
                tags += "[blocked_by: unified-plat-master-p2-02-trajectory-model]"
            return wave, tags
    return "E0", "[stream E][wave E0]"


def tags_for_python_refactor(source_id: str) -> str:
    f0 = {"py-01", "py-02"}
    f1 = {"py-03", "py-04", "py-05", "py-06", "py-07", "py-08", "py-09", "py-10", "py-11", "py-17", "py-18"}
    if source_id in f0:
        return "[stream F][wave F0]"
    if source_id in f1:
        return "[stream F][wave F1]"
    return "[stream F][wave F2]"


def yaml_quote(s: str) -> str:
    if not s or any(c in s for c in ':"#[]{}&*!|>%@`'):
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return s


def emit_todo_entry(
    uid: str,
    content: str,
    status: str,
    source: str,
    source_id: str,
) -> str:
    lines = [
        f"  - id: {uid}",
        f"    content: {yaml_quote(content)}",
        f"    status: {status}",
        f"    source: {source}",
        f"    source_id: {yaml_quote(source_id)}",
    ]
    return "\n".join(lines)


def split_frontmatter_body(text: str) -> tuple[str, str]:
    if not text.startswith("---"):
        return "", text
    parts = text.split("---", 2)
    if len(parts) < 3:
        return "", text
    return parts[1], parts[2].lstrip("\n")


def main() -> None:
    source_bodies: dict[str, str] = {}
    source_full: dict[str, str] = {}
    all_entries: list[str] = []
    index_rows: list[str] = []
    rollup = {"completed": 0, "pending": 0, "cancelled": 0, "in_progress": 0}

    for key, path in SOURCES.items():
        full = path.read_text()
        source_full[key] = full
        _, body = split_frontmatter_body(full)
        source_bodies[key] = body
        todos = parse_todos(full)
        prefix = {"deploy": "unified-dep", "platform": "unified-plat", "datasources": "unified-ds"}[key]
        for t in todos:
            uid = f"{prefix}-{t['id']}"
            content = t["content"]
            if key == "deploy":
                stream = "A"
                content = f"[stream A] {content}"
            elif key == "platform":
                wave, tags = tags_for_platform(t["id"])
                content = f"{tags} {content}"
            else:
                wave, tags = tags_for_ds(t["id"])
                content = f"{tags} {content}"
            if key == "platform":
                status = PLATFORM_STATUS_OVERRIDES.get(t["id"], t["status"])
            elif key == "datasources":
                status = DATASOURCE_STATUS_OVERRIDES.get(t["id"], t["status"])
            elif key == "deploy":
                status = DEPLOY_STATUS_OVERRIDES.get(t["id"], t["status"])
            else:
                status = t["status"]
            rollup[status] = rollup.get(status, 0) + 1
            all_entries.append(emit_todo_entry(uid, content, status, key, t["id"]))
            index_rows.append(f"| {uid} | {t['id']} | {key} | {status} |")

    for uid, content, status, source, sid in DEPLOY_EXTRA:
        content = f"[stream A] {content}"
        rollup[status] = rollup.get(status, 0) + 1
        all_entries.append(emit_todo_entry(uid, content, status, source, sid))
        index_rows.append(f"| {uid} | {sid} | {source} | {status} |")

    for uid, content, status, source, sid in QUEUE_TODOS:
        content = f"[stream B] {content}"
        rollup[status] = rollup.get(status, 0) + 1
        all_entries.append(emit_todo_entry(uid, content, status, source, sid))
        index_rows.append(f"| {uid} | {sid} | {source} | {status} |")

    for uid, content, status, source, sid in CATALOG_TODOS:
        content = f"[stream C] {content}"
        rollup[status] = rollup.get(status, 0) + 1
        all_entries.append(emit_todo_entry(uid, content, status, source, sid))
        index_rows.append(f"| {uid} | {sid} | {source} | {status} |")

    for uid, content, status, source, sid in PYTHON_REFACTOR_TODOS:
        content = f"{tags_for_python_refactor(sid)} {content}"
        rollup[status] = rollup.get(status, 0) + 1
        all_entries.append(emit_todo_entry(uid, content, status, source, sid))
        index_rows.append(f"| {uid} | {sid} | {source} | {status} |")

    total = len(all_entries)
    completed = rollup.get("completed", 0)
    pending = rollup.get("pending", 0) + rollup.get("in_progress", 0)
    cancelled = rollup.get("cancelled", 0)
    stream_a_count = sum(1 for e in all_entries if "[stream A]" in e)
    deploy_count = len(parse_todos(source_full["deploy"])) + len(DEPLOY_EXTRA)
    platform_count = len(parse_todos(source_full["platform"]))
    ds_count = len(parse_todos(source_full["datasources"]))
    new_count = len(QUEUE_TODOS) + len(CATALOG_TODOS) + len(DEPLOY_EXTRA) + len(PYTHON_REFACTOR_TODOS)

    body_sections = f'''# Egregore Unified Masterplan

Единый исполняемый backlog: сначала закрыть deploy gates, затем устранить корневую причину Kafka-очереди, параллельно запланировать Python runtime hardening, после этого убрать hybrid catalog seed и только потом продолжать platform/datasources waves.

**Merged:** {total} todos | completed {completed} | pending/in_progress {pending} | cancelled {cancelled}

**Source counts are exact for current source plans:** deploy imported {deploy_count - len(DEPLOY_EXTRA)}, platform imported {platform_count}, datasources imported {ds_count}, new queue/catalog/python/deploy-extra {new_count}. Earlier rough estimates in the meta-plan (~311) are superseded by this generated count.

---

## 1. Executive summary + critical path

| Order | Stream | Why it is here | Done when |
|-------|--------|----------------|-----------|
| 1 | **A DEPLOY** | Stabilize the currently deployed k3s path before refactors | P9/E2E/P7/P8 gates pass on `kafkapoll` |
| 2 | **B QUEUE** | Fix the root bottleneck: per-persona Kafka topics and one-partition consultant queue | single `worker.jobs`, N partitions, LAG=0 under parallel POST |
| 3 | **C CATALOG** | Remove runtime FS merge after queue path is stable | API seed/bootstrap only; prod never reads `agents/personas/*.yaml` |
| 4 | **D PLATFORM** | Rework orchestration around a shared RunKernel | D2 kernel contract unifies `ManageRun` and `RunWorkerJob` |
| 5 | **E DATASOURCES** | Add datasource RBAC on top of stable kernel/tool traces | E1 gateway authz and TraceEvent gates pass |
| 6 | **F PYTHON RUNTIME** | Harden async/resource/config/error patterns discovered from Python skills | no hidden event-loop/resource leaks; typed boundaries and tests cover refactor |

```mermaid
flowchart TD
  META[META done: unified file + audit]
  DEP_A[Stream A: deploy gates]
  QUE[Stream B: single worker.jobs]
  CAT[Stream C: API-only catalog seed]
  PY_F[Stream F: Python runtime hardening]
  PLAT_D2[Stream D2: RunKernel]
  DS_E1[Stream E1: datasource gateway]

  META --> DEP_A
  DEP_A --> QUE
  DEP_A -.->|parallel after evidence| PY_F
  PY_F -.->|feeds queue/resource cleanup| QUE
  QUE --> CAT
  CAT --> PLAT_D2
  PLAT_D2 --> DS_E1
  DEP_A -.->|parallel after META| PLAT_D0[Stream D0 inventories]
  DEP_A -.->|parallel after META| DS_E0[Stream E0 models/RBAC basics]
```

**Execution rule:** Stream D0, E0 and Stream F inventory may run in parallel with Stream A. F implementation should be sliced so it supports, not blocks, Stream B/C: lifecycle and async-boundary fixes first, broader typing/docs after queue stability. D1 starts after `unified-cat-04`; D2 starts after Stream B code is in place and Stream C seed policy is clear. E1 starts after D2 exposes the kernel/tool trace hooks.

---

## 2. Architecture decisions (ADR-lite)

### ADR-1: Single worker job queue

- **Decision:** One Kafka topic `worker.jobs` (partitions ≥ worker count). Job JSON carries `persona`; worker loads agent dynamically.
- **Rejects:** `worker.jobs.{{persona}}` per-topic (current) — causes serial bottleneck on consultant, consumer rebalance, LAG.
- **Migration:** drain old `worker.jobs.*` topics, deploy code writing to `worker.jobs`, then re-run E2E and lag gates before deleting/deprecating old topic helpers.
- **Files:** [`kafka_topics.py`](projects/egregore/cys_core/infrastructure/kafka_topics.py), [`kafka_queue.py`](projects/egregore/cys_core/infrastructure/kafka_queue.py), [`15-redpanda-topics-job.yaml`](deploy/k8s/cxado-offline/15-redpanda-topics-job.yaml)

### ADR-2: Dual orchestration → RunKernel (platform D2)

- **Today:** [`ManageRun`](projects/egregore/cys_core/application/use_cases/manage_run.py) (sync `/runs`) vs [`RunWorkerJob`](projects/egregore/cys_core/application/use_cases/run_worker_job.py) (Kafka).
- **Target:** Shared `RunKernelPort` (platform wave D2).
- **Dependency:** queue unification must land first so `RunWorkerJob` consumes the same job shape that the kernel contract will standardize.

### ADR-3: API-only catalog seed

- **Decision:** Production runtime reads Postgres catalog only. Seed via `POST /catalog/seed` + bootstrap script. FS merge in [`hybrid_registry.py`](projects/egregore/cys_core/infrastructure/catalog/hybrid_registry.py) → dev/test only (`USE_MEMORY_FALLBACK`).
- **Implication:** platform product packs seed through the API/bootstrap path; datasources use Postgres/API catalog adapters, not hybrid FS discovery.

### ADR-4: Datasource authorization subject and tracing

- **Decision:** datasource authz subject is the `persona` from the queue job payload (ADR-1), plus profile/tenant from the run context.
- **Trace dependency:** datasource policy/tool trace events depend on `unified-plat-master-p2-02-trajectory-model`; gateway enforcement depends on `unified-plat-master-p2-10-kernel-tool-hook`.

### ADR-5: Interim deploy (until ADR-1 shipped)

- `max_poll_interval_ms` in kafka consumer (local diff, tag `kafkapoll`)
- Operational drain: `kubectl rollout restart deploy/egregore-worker` when consultant LAG > 0

### ADR-6: Python runtime hardening without DDD breakage

- **Decision:** improve async/resource/error/config patterns only at layer boundaries: `interfaces/*`, `bootstrap/*`, `cys_core/application` ports/use cases, and `cys_core/infrastructure` adapters.
- **Do not:** import infrastructure into domain/application, move FastAPI concerns into domain, or add generic framework abstractions without a concrete failing call path.
- **Observed hotspots:** `asyncio.run` wrappers in Kafka publishers and queue sync methods, fire-and-forget `asyncio.create_task` in FastAPI and Redis bus dispatch, broad `except Exception` fallback to memory/False, per-message Kafka producers, sync `httpx.get` in tool adapters, async Redis/Kafka clients without explicit close hooks.
- **Pattern target:** async-first app paths, CLI-only sync wrappers, managed lifespan/background tasks, typed infrastructure ports, startup config validation, structured fallback metrics, and cancellation/resource tests.

---

## 3. Streams A–F + gates

| Stream/wave | Start after | Primary gate | Artifact |
|-------------|-------------|--------------|----------|
| A DEPLOY | META | `e2e-verify-egregore.sh` exit 0; consultant LAG=0; trace audit explains UI/Langfuse path | `deploy_logs/e2e_verify_*.log`, `deploy_logs/kafka_lag_*.md`, `deploy_logs/trace_audit_*.md` |
| B QUEUE | A gates or controlled parallel branch; re-run A gates after deploy | 2 parallel AD POST requests do not serialize/block; `worker.jobs` has N partitions and LAG=0 | `deploy_logs/kafka_migration_*.md` |
| C CATALOG | B code path stable | catalog version > 0 after bootstrap; prod mode never reads FS personas | `docs/CATALOG_SEED.md` |
| D0 PLATFORM inventory | META | inventories updated with `ManageRun`, queue split, and API-only catalog facts | inventory docs/tests in platform PR |
| D1 PLATFORM product packs | `unified-cat-04` | product packs seed through API/bootstrap, no hybrid wording | tests/docs in platform PR |
| D2 PLATFORM RunKernel | B + C policy clear | RunKernel contract tests green; interactive and worker paths share trace schema | pytest + E2E smoke |
| D3/D4 PLATFORM | D2 | tool/SGR/memory/eval/UI waves build on kernel trace contract | pytest/eval artifacts |
| E0 DATASOURCES | META | domain models + GET-only RBAC basics pass unit tests | pytest |
| E1 DATASOURCES | D2 tool hook | non-GET datasource denied at gateway; policy/tool TraceEvents emitted | pytest + trace sample |
| E2 DATASOURCES | D4/E1 | eval/governance docs and tests complete | eval/governance artifacts |
| F0 PYTHON inventory | META | hotspots documented with file paths and refactor slices | `docs/PYTHON_RUNTIME_HARDENING.md` or plan update |
| F1 PYTHON async/resources | A gates or controlled branch before B deploy | no hidden `asyncio.run` in app paths; Kafka/Redis/httpx resources close deterministically | unit/integration tests |
| F2 PYTHON typing/config/tests | F1 | startup config validation, typed ports/DTOs, fallback metrics, pytest fixtures/import-linter gates pass | pytest/import-linter/ruff |

Gate log template: [`deploy_logs/unified_gate_TEMPLATE.md`](deploy_logs/unified_gate_TEMPLATE.md)

---

## 4. Merged backlog by stream

| Stream | Todo count | Status now | Main blockers | Notes |
|--------|------------|------------|---------------|-------|
| A DEPLOY | {stream_a_count} | imported status preserved | Kafka backlog and `kafkapoll` deploy | Completed deploy todos stay completed; do not reopen them for Stream B refactor |
| B QUEUE | {len(QUEUE_TODOS)} | pending | A gates or a controlled parallel deploy branch | Supersedes per-persona Kafka helpers from completed deploy P1e/P2b |
| C CATALOG | {len(CATALOG_TODOS)} | pending | B code path stable | Supersedes platform `master-p1-06-seed-cybersec-product` implementation path |
| D PLATFORM | {platform_count} | pending | D1 after C, D2 after B/C | Execute by waves D0-D4, not by original phase order alone |
| E DATASOURCES | {ds_count} | pending | E1 after D2; E2 after D4/E1 | Catalog adapter is Postgres/API, not hybrid FS |
| F PYTHON RUNTIME | {len(PYTHON_REFACTOR_TODOS)} | pending | F1 after deploy evidence; keep DDD layers intact | Based on Python skills audit of async/config/errors/resources/tests |

### Stream A — DEPLOY

Immediate pending sequence: `unified-dep-kafka-max-poll` → P9 drain/pending/dequeue gates → P4 E2E poll/findings/logs → P7/P8 observability/UI gates → P5 benchmarks. This stream validates the current production path before Stream B changes the queue topology.

### Stream B — QUEUE

Implement as one focused queue PR/deploy: topic constant, enqueue path, consumer subscription, tests, k8s topic job, migration doc, deploy, lag gate, persona-group deprecation, architecture doc.

### Stream C — CATALOG

Implement after queue semantics are stable: inventory hybrid call sites, verify `SeedCatalog`, add bootstrap script/init job, remove production FS merge, keep FS fallback only for explicit dev/test memory fallback, add contract tests and docs.

### Stream D — PLATFORM

Wave order is D0 inventory → D1 product packs/API seed alignment → D2 RunKernel → D3 tools/SGR/memory/eval model work → D4 eval/UI/runbooks. Platform todos retain their original source IDs but execute through these wave tags.

### Stream E — DATASOURCES

Wave order is E0 models/RBAC defaults → E1 gateway enforcement and TraceEvent integration → E2 eval/governance. `ds-c3-01` and `ds-c3-02` are blocked by the platform trajectory model as well as the kernel tool hook.

### Stream F — PYTHON RUNTIME HARDENING

This stream is a refactor plan based on `fastapi-templates`, `async-python-patterns`, `python-testing-patterns`, `python-observability`, `python-error-handling`, `python-configuration`, `python-resilience`, `python-design-patterns`, `python-type-safety`, `python-background-jobs`, `python-resource-management`, and `uv-package-manager`.

| Wave | Focus | Files observed | Rule |
|------|-------|----------------|------|
| F0 | Inventory and contracts | `kafka_queue.py`, `kafka_events.py`, `kafka_control_events.py`, `interfaces/api/app.py`, `bus_transport.py`, `rate_limit.py`, `settings.py` | Document exact call paths before edits |
| F1 | Async/resource safety | Kafka queue/publishers, FastAPI lifespan tasks, Redis bus/rate limiter, HTTP clients | Async-first app paths; CLI-only sync wrappers; deterministic `aclose()` |
| F2 | Config/error/type/test hardening | `Settings`, application ports, WorkerJob payloads, metrics, pytest fixtures | Typed boundaries, fail-fast config, visible fallback metrics, no DDD layer inversion |

Initial findings to validate during F0:

- `KafkaJobQueue.enqueue/dequeue` and several Kafka publisher sync helpers call `asyncio.run`; keep these only in CLI/test adapters or replace with explicit async ports.
- `KafkaJobQueue`, Redis bus/rate limiter and one-shot Kafka producers lack a shared managed-resource lifecycle; add `aclose()` and tests for cancellation/timeout cleanup.
- FastAPI manual planner and Redis async handler dispatch use fire-and-forget tasks; move them under a small task supervisor with shutdown cancellation and exception capture.
- Kafka/Redis fallback paths often catch `Exception` and return `False` or memory fallback silently; replace with typed errors, structured logs and bounded Prometheus labels.
- HTTP tool adapters use ad hoc `httpx` clients/timeouts; centralize client creation/retry/timeout policy for SIEM/MCP/Veil/Veneno boundaries.
- `Settings` is typed but should validate enum-like fields, timeout ordering, required Kafka bootstrap when `USE_KAFKA=1`, and unsafe default secrets in prod.
- Hot paths still pass raw `dict[str, Any]` job/result payloads; introduce DTOs at ingress/worker/infrastructure boundaries only, preserving domain/application dependency direction.

---

## 5. Todo index (source_id → unified_id)

| unified_id | source_id | source | status |
|------------|-----------|--------|--------|
''' + "\n".join(index_rows) + f"\n\n---\n\n## 6. Status rollup\n\n| Status | Count |\n|--------|-------|\n| completed | {rollup.get('completed', 0)} |\n| pending | {rollup.get('pending', 0)} |\n| in_progress | {rollup.get('in_progress', 0)} |\n| cancelled | {rollup.get('cancelled', 0)} |\n| **total** | **{total}** |\n\n| Source | Count |\n|--------|-------|\n| deploy imported | {deploy_count - len(DEPLOY_EXTRA)} |\n| platform imported | {platform_count} |\n| datasources imported | {ds_count} |\n| new queue | {len(QUEUE_TODOS)} |\n| new catalog | {len(CATALOG_TODOS)} |\n| new python runtime hardening | {len(PYTHON_REFACTOR_TODOS)} |\n| new deploy extra | {len(DEPLOY_EXTRA)} |\n| **total** | **{total}** |\n\n**Status policy:** deploy statuses are carried over exactly, including completed/cancelled/in_progress. Platform, datasources, queue, catalog, Python runtime hardening, and deploy extra entries remain pending until implemented in the unified order above.\n\n---\n\n## Appendix A — reliable k3s deploy (FULL COPY, frozen 2026-07-03)\n\n```markdown\n{source_full['deploy'].rstrip()}\n```\n\n---\n\n## Appendix B — platform masterplan (FULL COPY)\n\n> **STALE SECTIONS:** assumes per-persona Kafka topics (`worker.jobs.*`) and hybrid FS+catalog seed. Superseded by Stream B (ADR-1) and Stream C (ADR-3). Keep for historical micro-phase detail; execute via unified frontmatter waves.\n\n```markdown\n{source_full['platform'].rstrip()}\n```\n\n---\n\n## Appendix C — datasources RBAC (FULL COPY)\n\n> **ALIGNMENT:** DataSource catalog is Postgres/API, not hybrid FS. `ds-c3-01` and `ds-c3-02` depend on `unified-plat-master-p2-02-trajectory-model`; gateway authz depends on `unified-plat-master-p2-10-kernel-tool-hook`. Authz subject is persona from job payload (ADR-1).\n\n```markdown\n{source_full['datasources'].rstrip()}\n```\n"

    frontmatter = f"""---
name: Egregore Unified Masterplan
overview: "Unified backlog: deploy gates (Stream A) → single worker.jobs queue (B) → API-only catalog (C) → platform RunKernel (D) → datasources RBAC (E) + Python runtime hardening (F). {total} micro-todos."
todos:
{chr(10).join(all_entries)}
isProject: false
---

"""

    OUT.write_text(frontmatter + body_sections)
    print(f"Wrote {OUT} ({total} todos)")


if __name__ == "__main__":
    main()
