#!/usr/bin/env python3
"""Build Grafana dashboards with enterprise design system."""
from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "deploy/observability/grafana/dashboards"

DS_PROM = {"type": "prometheus", "uid": "prometheus"}
DS_LOKI = {"type": "loki", "uid": "loki"}
DS_TEMPO = {"type": "tempo", "uid": "tempo"}

# Enterprise dark palette
C_SUCCESS = "#73BF69"
C_WARNING = "#FFB357"
C_ERROR = "#F2495C"
C_INFO = "#5794F2"
C_ACCENT = "#F2CC0C"
C_RED = C_ERROR
C_WARN = C_WARNING
C_GREEN = C_SUCCESS
C_BLUE = C_INFO
C_YELLOW = C_ACCENT

RI = "[$__rate_interval]"
ZERO = " or vector(0)"

TS_CUSTOM = {
    "drawStyle": "line",
    "fillOpacity": 10,
    "lineWidth": 1,
    "showPoints": "never",
    "spanNulls": False,
}
TS_OPTIONS = {
    "legend": {
        "calcs": ["mean", "max"],
        "displayMode": "table",
        "placement": "bottom",
        "showLegend": True,
    },
    "tooltip": {"mode": "multi", "sort": "desc"},
}

PERSONA = 'persona=~"$persona"'


def dash_link(title: str, uid: str) -> dict:
    return {
        "title": title,
        "type": "link",
        "icon": "dashboard",
        "url": f"/d/{uid}",
        "keepTime": True,
        "asDropdown": False,
        "targetBlank": False,
    }


def prom_target(expr: str, legend: str = "", ref: str = "A") -> dict:
    t = {
        "datasource": deepcopy(DS_PROM),
        "expr": expr,
        "refId": ref,
        "range": True,
    }
    if legend:
        t["legendFormat"] = legend
    return t


def ts_field(unit: str = "ops", decimals: int | None = None, overrides: list | None = None) -> dict:
    d: dict = {
        "color": {"mode": "palette-classic"},
        "custom": deepcopy(TS_CUSTOM),
        "unit": unit,
    }
    if decimals is not None:
        d["decimals"] = decimals
    return {"defaults": d, "overrides": overrides or []}


def row(panel_id: int, title: str, y: int) -> dict:
    return {
        "collapsed": False,
        "gridPos": {"h": 1, "w": 24, "x": 0, "y": y},
        "id": panel_id,
        "title": title,
        "type": "row",
    }


def health_stat(panel_id: int, title: str, expr: str, x: int, y: int, w: int = 4, desc: str = "") -> dict:
    return {
        "datasource": deepcopy(DS_PROM),
        "description": desc or f"Scrape target health for {title}.",
        "fieldConfig": {
            "defaults": {
                "mappings": [
                    {
                        "type": "value",
                        "options": {
                            "0": {"text": "DOWN", "color": C_ERROR},
                            "1": {"text": "UP", "color": C_SUCCESS},
                        },
                    }
                ],
                "thresholds": {
                    "mode": "absolute",
                    "steps": [
                        {"color": C_ERROR, "value": None},
                        {"color": C_SUCCESS, "value": 1},
                    ],
                },
            },
            "overrides": [],
        },
        "gridPos": {"h": 4, "w": w, "x": x, "y": y},
        "id": panel_id,
        "options": {
            "colorMode": "background",
            "graphMode": "none",
            "justifyMode": "center",
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
            "textMode": "auto",
        },
        "title": title,
        "type": "stat",
        "targets": [prom_target(expr, ref="A")],
    }


def kpi_stat(
    panel_id: int,
    title: str,
    expr: str,
    x: int,
    y: int,
    w: int,
    h: int = 4,
    unit: str = "short",
    decimals: int | None = None,
    description: str = "",
    thresholds: list | None = None,
    graph_mode: str = "area",
) -> dict:
    steps = thresholds or [
        {"color": C_SUCCESS, "value": None},
        {"color": C_WARNING, "value": 5},
        {"color": C_ERROR, "value": 10},
    ]
    defaults: dict = {
        "color": {"mode": "thresholds"},
        "thresholds": {"mode": "absolute", "steps": steps},
        "unit": unit,
    }
    if decimals is not None:
        defaults["decimals"] = decimals
    return {
        "datasource": deepcopy(DS_PROM),
        "description": description,
        "fieldConfig": {"defaults": defaults, "overrides": []},
        "gridPos": {"h": h, "w": w, "x": x, "y": y},
        "id": panel_id,
        "options": {
            "colorMode": "value",
            "graphMode": graph_mode,
            "justifyMode": "center",
            "orientation": "auto",
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
            "textMode": "auto",
        },
        "title": title,
        "type": "stat",
        "targets": [prom_target(expr, ref="A")],
    }


def gauge_panel(
    panel_id: int,
    title: str,
    expr: str,
    x: int,
    y: int,
    w: int,
    h: int = 4,
    unit: str = "short",
    max_val: float = 10,
    description: str = "",
    thresholds: list | None = None,
) -> dict:
    steps = thresholds or [
        {"color": C_SUCCESS, "value": None},
        {"color": C_WARNING, "value": 1},
        {"color": C_ERROR, "value": 5},
    ]
    return {
        "datasource": deepcopy(DS_PROM),
        "description": description,
        "fieldConfig": {
            "defaults": {
                "color": {"mode": "thresholds"},
                "max": max_val,
                "min": 0,
                "thresholds": {"mode": "absolute", "steps": steps},
                "unit": unit,
            },
            "overrides": [],
        },
        "gridPos": {"h": h, "w": w, "x": x, "y": y},
        "id": panel_id,
        "options": {
            "orientation": "auto",
            "reduceOptions": {"calcs": ["lastNotNull"]},
            "showThresholdLabels": False,
            "showThresholdMarkers": True,
        },
        "title": title,
        "type": "gauge",
        "targets": [prom_target(expr, ref="A")],
    }


def timeseries(
    panel_id: int,
    title: str,
    targets: list[dict],
    x: int,
    y: int,
    w: int,
    h: int = 8,
    unit: str = "ops",
    description: str = "",
    overrides: list | None = None,
    draw_style: str = "line",
) -> dict:
    fc = ts_field(unit, overrides=overrides)
    fc["defaults"]["custom"]["drawStyle"] = draw_style
    if draw_style == "bars":
        fc["defaults"]["custom"]["fillOpacity"] = 80
    return {
        "datasource": deepcopy(DS_PROM),
        "description": description,
        "fieldConfig": fc,
        "gridPos": {"h": h, "w": w, "x": x, "y": y},
        "id": panel_id,
        "options": deepcopy(TS_OPTIONS),
        "title": title,
        "type": "timeseries",
        "targets": targets,
    }


def dash_meta(
    uid: str,
    title: str,
    description: str,
    tags: list[str],
    links: list | None = None,
    templating: list | None = None,
    refresh: str = "30s",
) -> dict:
    return {
        "uid": uid,
        "title": title,
        "description": description,
        "tags": tags,
        "timezone": "browser",
        "schemaVersion": 39,
        "version": 1,
        "refresh": refresh,
        "graphTooltip": 1,
        "style": "dark",
        "editable": True,
        "fiscalYearStartMonth": 0,
        "time": {"from": "now-6h", "to": "now"},
        "annotations": {"list": []},
        "links": links or [],
        "templating": {"list": templating or []},
    }


def query_var(name: str, label: str, query: str, multi: bool = True) -> dict:
    return {
        "current": {"selected": True, "text": "All", "value": "$__all"},
        "datasource": deepcopy(DS_PROM),
        "definition": query,
        "hide": 0,
        "includeAll": True,
        "label": label,
        "multi": multi,
        "name": name,
        "query": {"query": query, "refId": f"Prometheus-{name}"},
        "refresh": 2,
        "sort": 1,
        "type": "query",
    }


def persona_templating() -> list:
    return [query_var("persona", "Persona", "label_values(cys_worker_job_duration_seconds_count, persona)")]


def veil_service_templating() -> list:
    return [query_var("service", "Service", "label_values(veil_http_requests_total, service)")]


def build_cxado_overview() -> dict:
    d = dash_meta(
        "cxado-overview",
        "CXado — Executive Overview",
        "Executive platform landing: cross-service health, KPIs, and drill-down links.",
        ["cxado", "platform", "production", "executive"],
        links=[
            dash_link("cys-agi SOC", "egregore-cys-agi"),
            dash_link("Egregore Logs & Traces", "egregore-observability"),
            dash_link("SGR Reasoning", "egregore-sgr"),
            dash_link("Veil HTTP RED", "veil-graph"),
            dash_link("Veil Logs & Traces", "veil-observability"),
            dash_link("vLLM Monitoring", "vllm-monitoring-exec"),
            dash_link("Infra / Host", "cxado-infra-host"),
            dash_link("Infra / K3s", "cxado-infra-k3s"),
        ],
    )
    d["version"] = 4
    y = 0
    panels = [row(100, "Platform Health", y)]
    y += 1
    health_jobs = [
        ("Egregore API", 'up{job="egregore-api"}'),
        ("Veil API", 'up{job="veil-api"}'),
        ("Veil MCP", 'up{job="veil-mcp"}'),
        ("vLLM", 'up{job="vllm"}'),
        ("Prometheus", 'up{job="prometheus"}'),
        ("Tempo", 'up{job="tempo"}'),
        ("Loki", 'up{job="loki"}'),
    ]
    for i, (title, expr) in enumerate(health_jobs):
        panels.append(health_stat(2 + i, title, expr, (i % 4) * 3, y + (i // 4) * 4, 3))
    y += 8
    panels.append(row(110, "Executive Summary", y))
    y += 1
    panels += [
        gauge_panel(
            20,
            "HITL Pending",
            f"cys_hitl_pending_total{ZERO}",
            0,
            y,
            6,
            description="Human-in-the-loop approvals awaiting action. Shows 0 when metric not yet emitted.",
            max_val=20,
        ),
        kpi_stat(
            21,
            "Active Investigations",
            f"cys_investigations_active{ZERO}",
            6,
            y,
            6,
            description="Currently active security investigations.",
            thresholds=[{"color": C_INFO, "value": None}],
            graph_mode="none",
        ),
        kpi_stat(
            22,
            "Events / sec",
            f"sum(rate(cys_events_ingested_total{RI})){ZERO}",
            12,
            y,
            6,
            unit="ops",
            decimals=2,
            description="Platform event ingestion rate.",
            thresholds=[{"color": C_SUCCESS, "value": None}],
        ),
        kpi_stat(
            23,
            "Veil 5xx / sec",
            f'sum(rate(veil_http_requests_total{{status=~"5.."}}{RI})){ZERO}',
            18,
            y,
            6,
            unit="ops",
            decimals=3,
            description="Veil server error rate across all services.",
            thresholds=[
                {"color": C_SUCCESS, "value": None},
                {"color": C_WARNING, "value": 0.01},
                {"color": C_ERROR, "value": 0.1},
            ],
            graph_mode="none",
        ),
    ]
    d["panels"] = panels
    return d


def build_egregore_cys_agi() -> dict:
    d = dash_meta(
        "egregore-cys-agi",
        "cys-agi — SOC Platform",
        "cys-agi SOC deep dive: workers, tools, security, RAG, cost, and trust. Executive KPIs on CXado Overview.",
        ["cys-agi", "soc", "security", "egregore"],
        links=[
            dash_link("CXado Overview", "cxado-overview"),
            dash_link("Egregore Logs & Traces", "egregore-observability"),
            dash_link("SGR Reasoning", "egregore-sgr"),
        ],
        templating=persona_templating(),
    )
    pf = PERSONA
    y = 0
    panels = [row(100, "Scrape Health", y)]
    y += 1
    scrape_jobs = [
        (101, "API", 'up{job="egregore-api"}', 0),
        (103, "Prometheus", 'up{job="prometheus"}', 6),
        (104, "Tempo", 'up{job="tempo"}', 12),
        (106, "Loki", 'up{job="loki"}', 18),
    ]
    for pid, title, expr, x in scrape_jobs:
        panels.append(health_stat(pid, title, expr, x, y, 6))
    y += 4

    panels.append(row(120, "Ingress & Workers", y))
    y += 1
    panels += [
        timeseries(
            1,
            "Event Ingestion Rate",
            [prom_target(f"sum(rate(cys_events_ingested_total{RI})) by (event_type)", "{{event_type}}")],
            0,
            y,
            12,
            description="Event ingestion rate by type.",
        ),
        timeseries(
            2,
            "Worker Job Duration P95",
            [
                prom_target(
                    f"histogram_quantile(0.95, sum(rate(cys_worker_job_duration_seconds_bucket{{{pf}}}{RI})) by (le, persona))",
                    "{{persona}}",
                )
            ],
            12,
            y,
            12,
            unit="s",
            description="Worker job latency p95 by persona.",
        ),
        timeseries(
            121,
            "Worker Job Rate",
            [
                prom_target(
                    f"sum(rate(cys_worker_job_duration_seconds_count{{{pf}}}{RI})) by (persona, status)",
                    "{{persona}} {{status}}",
                )
            ],
            0,
            y + 8,
            24,
            description="Worker job throughput by persona and status.",
            draw_style="bars",
        ),
    ]
    y += 16

    panels.append(row(130, "Security", y))
    y += 1
    panels += [
        timeseries(
            4,
            "Sanitizer Block Rate",
            [prom_target(f"sum(rate(cys_sanitizer_blocks_total{RI})) by (source, verdict)", "{{source}} {{verdict}}")],
            0,
            y,
            12,
            description="Input sanitizer blocks by source and verdict.",
        ),
        timeseries(
            131,
            "Approval Bypass Attempts",
            [
                prom_target(
                    f"sum(rate(cys_approval_bypass_attempts_total{RI})) by (reason)",
                    "{{reason}}",
                )
            ],
            12,
            y,
            12,
            description="Rejected HITL resume attempts.",
            overrides=[
                {
                    "matcher": {"id": "byRegexp", "options": "/.*/"},
                    "properties": [{"id": "color", "value": {"fixedColor": C_ERROR, "mode": "fixed"}}],
                }
            ],
        ),
    ]
    y += 8

    panels.append(row(140, "RAG & Tools", y))
    y += 1
    panels += [
        timeseries(
            141,
            "RAG Retrieval Rate",
            [prom_target(f"sum(rate(cys_rag_retrievals_total{RI})) by (tenant, denied)", "{{tenant}} denied={{denied}}")],
            0,
            y,
            12,
            description="RAG retrieval attempts by tenant.",
        ),
        timeseries(
            142,
            "Tool Invocation Rate",
            [prom_target(f"sum(rate(cys_tool_invocations_total{RI})) by (tool, result)", "{{tool}} {{result}}")],
            12,
            y,
            12,
            description="MCP tool invocations by tool and result.",
        ),
    ]
    y += 8

    panels.append(row(150, "Cost & Trust", y))
    y += 1
    panels += [
        timeseries(
            151,
            "Token Throughput",
            [prom_target(f"sum(rate(cys_job_tokens_total{{{pf}}}{RI})) by (persona)", "{{persona}}")],
            0,
            y,
            12,
            unit="short",
            description="Estimated tokens consumed per second by persona.",
        ),
        timeseries(
            152,
            "Cost Rate (USD / sec)",
            [prom_target(f"sum(rate(cys_job_cost_usd_total{{{pf}}}{RI})) by (persona)", "{{persona}}")],
            12,
            y,
            12,
            unit="currencyUSD",
            description="Estimated USD cost per second by persona.",
        ),
        timeseries(
            153,
            "Agent Trust Score",
            [prom_target(f"cys_agent_trust_score{{{pf}}}", "{{persona}}")],
            0,
            y + 8,
            24,
            unit="short",
            description="Configured trust score per persona.",
        ),
    ]
    y += 16

    panels.append(row(170, "Policy", y))
    y += 1
    panels.append(
        timeseries(
            171,
            "Catalog Version",
            [prom_target("cys_catalog_version", "{{profile_id}}")],
            0,
            y,
            12,
            unit="short",
            description="Policy catalog version by profile.",
        )
    )
    d["panels"] = panels
    return d


def veil_obs_templating() -> list:
    return [
        {
            "name": "namespace",
            "type": "custom",
            "label": "Namespace",
            "query": "veil",
            "current": {"text": "veil", "value": "veil"},
            "options": [{"text": "veil", "value": "veil", "selected": True}],
        },
        *veil_service_templating(),
        {
            "name": "trace_id",
            "type": "textbox",
            "label": "Trace ID",
            "current": {"text": "", "value": ""},
        },
    ]


def build_veil_observability() -> dict:
    d = dash_meta(
        "veil-observability",
        "Veil — Logs & Traces",
        "Veil log aggregation, distributed traces, and messaging plane health. HTTP RED lives on Veil Graph.",
        ["veil", "loki", "tempo", "observability", "production"],
        links=[
            dash_link("CXado Overview", "cxado-overview"),
            dash_link("Veil Graph", "veil-graph"),
        ],
        templating=veil_obs_templating(),
    )
    note = (
        "In graph-only mode ingest/pipeline workers are scaled to 0. "
        "Enable workers via values-workers-obs.yaml for full data-plane metrics."
    )
    d["description"] = f"{d['description']} {note}"
    y = 0
    panels = [row(100, "Service Health", y)]
    y += 1
    panels += [
        health_stat(2, "Veil API", 'up{job="veil-api"}', 0, y, 4),
        health_stat(3, "Veil MCP", 'up{job="veil-mcp"}', 4, y, 4),
        health_stat(
            4,
            "NATS",
            '(sum(kube_pod_status_phase{namespace="veil-data",pod=~"nats.*",phase="Running"}) >= bool 1)',
            8,
            y,
            4,
            desc="NATS pod running (requires kube-state-metrics).",
        ),
    ]
    y += 4
    panels.append(row(110, "Logs", y))
    y += 1
    panels.append(
        {
            "datasource": deepcopy(DS_LOKI),
            "description": "Veil pod logs filtered by namespace, service, and trace ID.",
            "gridPos": {"h": 10, "w": 24, "x": 0, "y": y},
            "id": 41,
            "options": {"showTime": True, "showLabels": True, "wrapLogMessage": True},
            "title": "Veil Pod Logs",
            "type": "logs",
            "targets": [
                {
                    "datasource": deepcopy(DS_LOKI),
                    "expr": '{namespace="$namespace", app=~"$service"} | json | trace_id=~"${trace_id:pipe}.*"',
                    "refId": "A",
                }
            ],
        }
    )
    y += 10
    panels.append(row(120, "Traces", y))
    y += 1
    panels.append(
        {
            "datasource": deepcopy(DS_TEMPO),
            "description": "Recent distributed traces for veil-mcp.",
            "gridPos": {"h": 10, "w": 24, "x": 0, "y": y},
            "id": 51,
            "options": {},
            "title": "Veil MCP Traces",
            "type": "traces",
            "targets": [
                {
                    "datasource": deepcopy(DS_TEMPO),
                    "queryType": "traceqlSearch",
                    "query": '{ resource.service.name = "veil-mcp" }',
                    "refId": "A",
                }
            ],
        }
    )
    d["panels"] = panels
    return d


VEIL_HTTP_OVERRIDES = [
    {
        "matcher": {"id": "byRegexp", "options": "/5xx|5..|error/i"},
        "properties": [{"id": "color", "value": {"fixedColor": C_ERROR, "mode": "fixed"}}],
    },
    {
        "matcher": {"id": "byRegexp", "options": "/p95|p99|latency/i"},
        "properties": [{"id": "color", "value": {"fixedColor": C_WARNING, "mode": "fixed"}}],
    },
    {
        "matcher": {"id": "byRegexp", "options": "/rate|req/i"},
        "properties": [{"id": "color", "value": {"fixedColor": C_INFO, "mode": "fixed"}}],
    },
]


def build_veil_graph() -> dict:
    d = dash_meta(
        "veil-graph",
        "Veil Graph — HTTP RED",
        "Canonical Veil HTTP metrics: request rate, latency percentiles, and server errors.",
        ["veil", "graph", "production", "red"],
        links=[
            dash_link("CXado Overview", "cxado-overview"),
            dash_link("Veil Logs & Traces", "veil-observability"),
        ],
        templating=veil_service_templating(),
    )
    svc = 'service=~"$service"'
    y = 0
    panels = [row(100, "Scrape Health", y)]
    y += 1
    panels += [
        health_stat(2, "Veil API", 'up{job="veil-api"}', 0, y, 4),
        health_stat(3, "Veil MCP", 'up{job="veil-mcp"}', 4, y, 4),
        kpi_stat(
            4,
            "Total Request Rate",
            f'sum(rate(veil_http_requests_total{{{svc}}}{RI})){ZERO}',
            8,
            y,
            8,
            unit="ops",
            decimals=2,
            description="Aggregate HTTP request rate across selected services.",
            thresholds=[{"color": C_INFO, "value": None}],
        ),
    ]
    y += 4
    panels.append(row(110, "Latency & Experience", y))
    y += 1
    panels += [
        timeseries(
            11,
            "Request Rate by Service",
            [
                prom_target(
                    f'sum(rate(veil_http_requests_total{{{svc}}}{RI})) by (service, method)',
                    "{{service}} {{method}}",
                )
            ],
            0,
            y,
            12,
            description="HTTP request rate — RED Rate.",
            overrides=VEIL_HTTP_OVERRIDES,
        ),
        timeseries(
            12,
            "Latency P95 / P99",
            [
                prom_target(
                    f"histogram_quantile(0.95, sum(rate(veil_http_request_duration_seconds_bucket{{{svc}}}{RI})) by (le, service))",
                    "{{service}} p95",
                ),
                prom_target(
                    f"histogram_quantile(0.99, sum(rate(veil_http_request_duration_seconds_bucket{{{svc}}}{RI})) by (le, service))",
                    "{{service}} p99",
                    ref="B",
                ),
            ],
            12,
            y,
            12,
            unit="s",
            description="End-to-end HTTP latency percentiles — RED Duration.",
            overrides=VEIL_HTTP_OVERRIDES,
        ),
        timeseries(
            13,
            "5xx Error Rate",
            [
                prom_target(
                    f'sum(rate(veil_http_requests_total{{status=~"5..",{svc}}}{RI})) by (service, route)',
                    "{{service}} {{route}}",
                )
            ],
            0,
            y + 8,
            24,
            description="Server error responses — RED Errors.",
            overrides=[
                {
                    "matcher": {"id": "byRegexp", "options": "/.*/"},
                    "properties": [{"id": "color", "value": {"fixedColor": C_ERROR, "mode": "fixed"}}],
                }
            ],
        ),
    ]
    d["panels"] = panels
    return d


def egregore_obs_templating() -> list:
    return [
        {
            "name": "namespace",
            "type": "custom",
            "label": "Namespace",
            "query": "cxado-app",
            "current": {"text": "cxado-app", "value": "cxado-app"},
            "options": [{"text": "cxado-app", "value": "cxado-app", "selected": True}],
            "hide": 0,
        },
        {
            "name": "service",
            "type": "custom",
            "label": "Service",
            "query": "egregore-api,egregore-worker",
            "includeAll": True,
            "allValue": "egregore-.*",
            "multi": True,
            "current": {"text": "All", "value": "$__all"},
            "options": [
                {"text": "All", "value": "$__all", "selected": True},
                {"text": "egregore-api", "value": "egregore-api", "selected": False},
                {"text": "egregore-worker", "value": "egregore-worker", "selected": False},
            ],
            "hide": 0,
        },
        {
            "name": "correlation_id",
            "type": "textbox",
            "label": "Correlation ID",
            "current": {"text": "", "value": ""},
            "hide": 0,
        },
    ]


def build_egregore_observability() -> dict:
    d = dash_meta(
        "egregore-observability",
        "Egregore — Logs & Traces",
        "Egregore application logs and distributed traces. Metrics on cys-agi SOC; executive KPIs on CXado Overview.",
        ["egregore", "loki", "tempo", "observability", "production"],
        links=[
            dash_link("CXado Overview", "cxado-overview"),
            dash_link("cys-agi SOC", "egregore-cys-agi"),
            dash_link("SGR Reasoning", "egregore-sgr"),
        ],
        templating=egregore_obs_templating(),
    )
    y = 0
    panels = [row(100, "Health", y)]
    y += 1
    panels.append(
        health_stat(
            2,
            "Egregore API",
            'up{job="egregore-api"}',
            0,
            y,
            6,
            desc="Full scrape health on cys-agi SOC dashboard.",
        )
    )
    y += 4
    panels.append(row(110, "Logs", y))
    y += 1
    panels += [
        {
            "datasource": deepcopy(DS_LOKI),
            "description": "Egregore application logs with optional correlation ID filter.",
            "gridPos": {"h": 12, "w": 24, "x": 0, "y": y},
            "id": 21,
            "options": {
                "showTime": True,
                "showLabels": True,
                "showCommonLabels": False,
                "wrapLogMessage": True,
                "prettifyLogMessage": False,
                "enableLogDetails": True,
                "dedupStrategy": "none",
                "sortOrder": "Descending",
            },
            "title": "Application Logs",
            "type": "logs",
            "targets": [
                {
                    "datasource": deepcopy(DS_LOKI),
                    "expr": '{namespace="$namespace", app=~"$service"} | json | correlation_id=~"${correlation_id:pipe}.*"',
                    "refId": "A",
                }
            ],
        },
        {
            "datasource": deepcopy(DS_LOKI),
            "description": "Error-level logs only.",
            "gridPos": {"h": 8, "w": 24, "x": 0, "y": y + 12},
            "id": 22,
            "options": {
                "showTime": True,
                "showLabels": True,
                "wrapLogMessage": True,
                "enableLogDetails": True,
                "sortOrder": "Descending",
            },
            "title": "Error Logs",
            "type": "logs",
            "targets": [
                {
                    "datasource": deepcopy(DS_LOKI),
                    "expr": '{namespace="$namespace", app=~"$service", level="error"} | json',
                    "refId": "A",
                }
            ],
        },
    ]
    y += 20
    panels.append(row(120, "Traces", y))
    y += 1
    panels += [
        {
            "datasource": deepcopy(DS_TEMPO),
            "description": "Recent Egregore distributed traces.",
            "gridPos": {"h": 12, "w": 24, "x": 0, "y": y},
            "id": 31,
            "options": {},
            "title": "Egregore Traces",
            "type": "traces",
            "targets": [
                {
                    "datasource": deepcopy(DS_TEMPO),
                    "queryType": "traceqlSearch",
                    "query": '{resource.service.name=~"egregore-.*"}',
                    "limit": 20,
                    "refId": "A",
                }
            ],
        },
        timeseries(
            32,
            "Tempo Span Ingress Rate",
            [prom_target(f"sum(rate(tempo_distributor_spans_received_total{RI}))", "spans/s")],
            0,
            y + 12,
            24,
            description="Tempo distributor span ingress — indicates trace pipeline health, not Egregore-only rate.",
        ),
    ]
    d["panels"] = panels
    return d


def build_sgr() -> dict:
    d = dash_meta(
        "egregore-sgr",
        "SGR Reasoning — Middleware",
        "SGR reasoning middleware: step throughput, iron parse retries, and retry ratio.",
        ["egregore", "sgr", "middleware", "production"],
        links=[
            dash_link("CXado Overview", "cxado-overview"),
            dash_link("cys-agi SOC", "egregore-cys-agi"),
            dash_link("Egregore Logs & Traces", "egregore-observability"),
        ],
    )
    y = 0
    panels = [row(100, "Executive Summary", y)]
    y += 1
    panels += [
        kpi_stat(
            1,
            "Reasoning Steps / sec",
            f"sum(rate(cys_sgr_reasoning_steps_total{RI})){ZERO}",
            0,
            y,
            8,
            description="SGR reasoning steps processed per second.",
            thresholds=[
                {"color": C_INFO, "value": None},
                {"color": C_SUCCESS, "value": 0.01},
            ],
            unit="ops",
            decimals=3,
        ),
        kpi_stat(
            2,
            "Iron Parse Retries / sec",
            f"sum(rate(cys_sgr_iron_parse_retries_total{RI})){ZERO}",
            8,
            y,
            8,
            description="Iron schema parse retries per second.",
            thresholds=[
                {"color": C_SUCCESS, "value": None},
                {"color": C_WARNING, "value": 0.1},
                {"color": C_ERROR, "value": 1},
            ],
            unit="ops",
            decimals=3,
        ),
        gauge_panel(
            3,
            "Retry Ratio",
            f"100 * sum(rate(cys_sgr_iron_parse_retries_total{RI})) / clamp_min(sum(rate(cys_sgr_reasoning_steps_total{RI})), 1e-9)",
            16,
            y,
            8,
            unit="percent",
            max_val=100,
            description="Retries as percentage of reasoning steps.",
            thresholds=[
                {"color": C_SUCCESS, "value": None},
                {"color": C_WARNING, "value": 5},
                {"color": C_ERROR, "value": 20},
            ],
        ),
    ]
    y += 4
    panels.append(row(110, "Trends", y))
    y += 1
    panels += [
        timeseries(
            4,
            "Reasoning Step Rate",
            [prom_target(f"sum(rate(cys_sgr_reasoning_steps_total{RI})){ZERO}", "steps/s")],
            0,
            y,
            12,
            description="Reasoning step throughput over time.",
        ),
        timeseries(
            5,
            "Iron Parse Retry Rate",
            [prom_target(f"sum(rate(cys_sgr_iron_parse_retries_total{RI})){ZERO}", "retries/s")],
            12,
            y,
            12,
            description="Iron parse retry rate over time.",
        ),
    ]
    d["panels"] = panels
    return d


def build_infra_host() -> dict:
    d = dash_meta(
        "cxado-infra-host",
        "Infra — Host (Node Exporter)",
        "Host-level metrics: CPU, memory, and disk utilization from node-exporter.",
        ["infra", "node-exporter", "host", "production"],
        refresh="30s",
        links=[
            dash_link("CXado Overview", "cxado-overview"),
            dash_link("Infra / K3s", "cxado-infra-k3s"),
            dash_link("vLLM Monitoring", "vllm-monitoring-exec"),
        ],
        templating=[query_var("instance", "Instance", 'label_values(up{job="node-exporter"}, instance)')],
    )
    inst = 'instance=~"$instance"'
    y = 0
    panels = [row(100, "Host Summary", y)]
    y += 1
    panels += [
        kpi_stat(
            1,
            "Disk Free (root)",
            f'min(node_filesystem_avail_bytes{{fstype!~"tmpfs|overlay",mountpoint="/",{inst}}})',
            0,
            y,
            6,
            unit="bytes",
            decimals=1,
            description="Available bytes on root filesystem.",
            thresholds=[
                {"color": C_ERROR, "value": None},
                {"color": C_WARNING, "value": 10737418240},
                {"color": C_SUCCESS, "value": 53687091200},
            ],
            graph_mode="none",
        ),
        kpi_stat(
            2,
            "Memory Available",
            f"min(node_memory_MemAvailable_bytes{{{inst}}})",
            6,
            y,
            6,
            unit="bytes",
            decimals=1,
            description="Available system memory.",
            thresholds=[
                {"color": C_ERROR, "value": None},
                {"color": C_WARNING, "value": 2147483648},
                {"color": C_SUCCESS, "value": 8589934592},
            ],
            graph_mode="area",
        ),
        gauge_panel(
            3,
            "CPU Utilization",
            f'100 * (1 - avg(rate(node_cpu_seconds_total{{mode="idle",{inst}}}{RI})))',
            12,
            y,
            6,
            unit="percent",
            max_val=100,
            description="Average CPU utilization.",
            thresholds=[
                {"color": C_SUCCESS, "value": None},
                {"color": C_WARNING, "value": 70},
                {"color": C_ERROR, "value": 90},
            ],
        ),
        gauge_panel(
            4,
            "Load Average (1m)",
            f'max(node_load1{{{inst}}}){ZERO}',
            18,
            y,
            6,
            unit="short",
            max_val=16,
            description="1-minute load average.",
            thresholds=[
                {"color": C_SUCCESS, "value": None},
                {"color": C_WARNING, "value": 4},
                {"color": C_ERROR, "value": 8},
            ],
        ),
    ]
    y += 4
    panels.append(row(110, "CPU & Memory", y))
    y += 1
    panels.append(
        timeseries(
            5,
            "CPU Utilization",
            [
                prom_target(
                    f'100 * (1 - avg(rate(node_cpu_seconds_total{{mode="idle",{inst}}}{RI})))',
                    "cpu",
                )
            ],
            0,
            y,
            24,
            unit="percent",
            description="CPU utilization over time.",
        )
    )
    y += 8
    panels.append(row(120, "Storage", y))
    y += 1
    panels.append(
        timeseries(
            7,
            "Disk Usage by Mountpoint",
            [
                prom_target(
                    f'100 * (1 - (node_filesystem_avail_bytes{{fstype!~"tmpfs|overlay",mountpoint!~"/run.*",{inst}}} / node_filesystem_size_bytes{{fstype!~"tmpfs|overlay",mountpoint!~"/run.*",{inst}}}))',
                    "{{mountpoint}}",
                )
            ],
            0,
            y,
            24,
            h=10,
            unit="percent",
            description="Filesystem utilization by mountpoint.",
        )
    )
    d["panels"] = panels
    return d


def build_infra_k3s() -> dict:
    d = dash_meta(
        "cxado-infra-k3s",
        "Infra — k3s (kube-state-metrics)",
        "Kubernetes cluster health: nodes, pods, phases, and container restarts.",
        ["infra", "kubernetes", "k3s", "kube-state-metrics", "production"],
        refresh="30s",
        links=[
            dash_link("CXado Overview", "cxado-overview"),
            dash_link("Infra / Host", "cxado-infra-host"),
        ],
        templating=[query_var("namespace", "Namespace", "label_values(kube_pod_info, namespace)")],
    )
    ns = 'namespace=~"$namespace"'
    y = 0
    panels = [row(100, "Cluster Summary", y)]
    y += 1
    panels += [
        kpi_stat(
            1,
            "Nodes Ready",
            'sum(kube_node_status_condition{condition="Ready",status="true"})',
            0,
            y,
            6,
            description="Number of nodes in Ready state.",
            thresholds=[
                {"color": C_ERROR, "value": None},
                {"color": C_WARNING, "value": 1},
                {"color": C_SUCCESS, "value": 2},
            ],
            graph_mode="none",
        ),
        kpi_stat(
            2,
            "Pods Running",
            f'sum(kube_pod_status_phase{{phase="Running",{ns}}})',
            6,
            y,
            6,
            description="Pods in Running phase.",
            thresholds=[{"color": C_INFO, "value": None}],
            graph_mode="none",
        ),
        gauge_panel(
            3,
            "Pods Not Ready",
            f'sum(kube_pod_status_phase{{phase=~"Pending|Failed|Unknown",{ns}}}){ZERO}',
            12,
            y,
            6,
            max_val=20,
            description="Pods not in Running or Succeeded phase.",
            thresholds=[
                {"color": C_SUCCESS, "value": None},
                {"color": C_WARNING, "value": 1},
                {"color": C_ERROR, "value": 5},
            ],
        ),
        kpi_stat(
            4,
            "Container Restarts / sec",
            f"sum(rate(kube_pod_container_status_restarts_total{{{ns}}}{RI})){ZERO}",
            18,
            y,
            6,
            description="Container restart rate.",
            thresholds=[
                {"color": C_SUCCESS, "value": None},
                {"color": C_WARNING, "value": 0.1},
                {"color": C_ERROR, "value": 1},
            ],
            unit="ops",
            decimals=3,
        ),
    ]
    y += 4
    panels.append(row(110, "Workload", y))
    y += 1
    panels += [
        timeseries(
            5,
            "Pods by Phase",
            [prom_target(f"sum by (phase) (kube_pod_status_phase{{{ns}}})", "{{phase}}")],
            0,
            y,
            12,
            unit="short",
            description="Pod count grouped by phase.",
        ),
        timeseries(
            6,
            "Container Restart Rate",
            [prom_target(f"sum(rate(kube_pod_container_status_restarts_total{{{ns}}}{RI})){ZERO}", "restarts/s")],
            12,
            y,
            12,
            description="Container restart rate over time.",
        ),
    ]
    d["panels"] = panels
    return d


def main() -> None:
    builders = {
        ROOT / "cxado/cxado-overview.json": build_cxado_overview,
        ROOT / "egregore/egregore-cys-agi.json": build_egregore_cys_agi,
        ROOT / "veil/veil-observability.json": build_veil_observability,
        ROOT / "veil/veil-graph.json": build_veil_graph,
        ROOT / "egregore/egregore-observability.json": build_egregore_observability,
        ROOT / "egregore/sgr-reasoning.json": build_sgr,
        ROOT / "infra/infra-host.json": build_infra_host,
        ROOT / "infra/infra-k3s.json": build_infra_k3s,
    }
    for path, fn in builders.items():
        path.write_text(json.dumps(fn(), indent=2) + "\n")
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
