#!/usr/bin/env python3
"""Build Grafana dashboards: dedup, no-data fixes, vLLM polish."""
from __future__ import annotations

import json
import re
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "deploy/observability/grafana/dashboards"

DS_PROM = {"type": "prometheus", "uid": "prometheus"}
DS_LOKI = {"type": "loki", "uid": "loki"}
DS_TEMPO = {"type": "tempo", "uid": "tempo"}

C_RED = "#F2495C"
C_WARN = "#FFB357"
C_GREEN = "#73BF69"
C_BLUE = "#5794F2"
C_YELLOW = "#F2CC0C"

RI = "[$__rate_interval]"
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


def text_panel(panel_id: int, title: str, content: str, x: int, y: int, w: int, h: int = 4) -> dict:
    return {
        "gridPos": {"h": h, "w": w, "x": x, "y": y},
        "id": panel_id,
        "options": {"mode": "markdown", "content": content},
        "title": title,
        "type": "text",
    }


def health_stat(panel_id: int, title: str, expr: str, x: int, y: int, w: int = 4, desc: str = "") -> dict:
    p = {
        "datasource": deepcopy(DS_PROM),
        "description": desc or f"Scrape target health for {title}.",
        "fieldConfig": {
            "defaults": {
                "mappings": [
                    {
                        "type": "value",
                        "options": {
                            "0": {"text": "DOWN", "color": C_RED},
                            "1": {"text": "UP", "color": C_GREEN},
                        },
                    }
                ],
                "thresholds": {
                    "mode": "absolute",
                    "steps": [
                        {"color": C_RED, "value": None},
                        {"color": C_GREEN, "value": 1},
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
    return p


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
        {"color": C_GREEN, "value": None},
        {"color": C_WARN, "value": 5},
        {"color": C_RED, "value": 10},
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
        {"color": C_GREEN, "value": None},
        {"color": C_WARN, "value": 1},
        {"color": C_RED, "value": 5},
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
) -> dict:
    return {
        "datasource": deepcopy(DS_PROM),
        "description": description,
        "fieldConfig": ts_field(unit, overrides=overrides),
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
    d["version"] = 3
    y = 0
    panels = [row(100, "Platform Health", y)]
    y += 1
    health_jobs = [
        ("Egregore API", 'up{job="egregore-api"}'),
        ("Veil API", 'up{job="veil-api"}'),
        ("Veil MCP", 'up{job="veil-mcp"}'),
        ("Prometheus", 'up{job="prometheus"}'),
        ("Tempo", 'up{job="tempo"}'),
        ("Loki", 'up{job="loki"}'),
    ]
    for i, (title, expr) in enumerate(health_jobs):
        panels.append(health_stat(2 + i, title, expr, i * 4, y, 4))
    y += 4
    panels.append(row(110, "Executive Summary", y))
    y += 1
    panels += [
        gauge_panel(
            20,
            "HITL Pending",
            "cys_hitl_pending_total or vector(0)",
            0,
            y,
            6,
            description="Human-in-the-loop approvals awaiting action.",
            max_val=20,
        ),
        kpi_stat(
            21,
            "Active Investigations",
            "cys_investigations_active or vector(0)",
            6,
            y,
            6,
            description="Currently active security investigations.",
            thresholds=[{"color": C_BLUE, "value": None}],
            graph_mode="none",
        ),
        kpi_stat(
            22,
            "Events / sec",
            f"sum(rate(cys_events_ingested_total{RI})) or vector(0)",
            12,
            y,
            6,
            unit="ops",
            decimals=2,
            description="Platform event ingestion rate.",
            thresholds=[{"color": C_GREEN, "value": None}],
        ),
        kpi_stat(
            23,
            "Veil 5xx / sec",
            f'sum(rate(veil_http_requests_total{{status=~"5.."}}{RI})) or vector(0)',
            18,
            y,
            6,
            unit="ops",
            decimals=3,
            description="Veil server error rate across all services.",
            thresholds=[
                {"color": C_GREEN, "value": None},
                {"color": C_WARN, "value": 0.01},
                {"color": C_RED, "value": 0.1},
            ],
            graph_mode="none",
        ),
    ]
    d["panels"] = panels
    return d


def veil_templating() -> list:
    return [
        {
            "name": "namespace",
            "type": "custom",
            "label": "Namespace",
            "query": "veil",
            "current": {"text": "veil", "value": "veil"},
            "options": [{"text": "veil", "value": "veil", "selected": True}],
        },
        {
            "name": "service",
            "type": "custom",
            "label": "Service",
            "query": "veil-api,veil-mcp,veil-ingest-worker,veil-pipeline-worker",
            "includeAll": True,
            "allValue": "veil-.*",
            "multi": True,
            "current": {"text": "All", "value": "$__all"},
        },
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
        templating=veil_templating(),
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
        health_stat(2, "veil-api", 'up{job="veil-api"}', 0, y, 4),
        health_stat(3, "veil-mcp", 'up{job="veil-mcp"}', 4, y, 4),
        health_stat(4, "NATS", '(sum(kube_pod_status_phase{namespace="veil-data",pod=~"nats.*",phase="Running"}) >= bool 1)', 8, y, 4,
                    desc="NATS pod running (kube-state-metrics). Prometheus /varz scrape is not exposition format."),
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
            "title": "Tempo — veil-mcp",
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
        "properties": [{"id": "color", "value": {"fixedColor": C_RED, "mode": "fixed"}}],
    },
    {
        "matcher": {"id": "byRegexp", "options": "/p95|p99|latency/i"},
        "properties": [{"id": "color", "value": {"fixedColor": C_WARN, "mode": "fixed"}}],
    },
    {
        "matcher": {"id": "byRegexp", "options": "/rate|req/i"},
        "properties": [{"id": "color", "value": {"fixedColor": C_BLUE, "mode": "fixed"}}],
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
        templating=[
            {
                "current": {"selected": True, "text": "All", "value": "$__all"},
                "datasource": deepcopy(DS_PROM),
                "definition": "label_values(veil_http_requests_total, service)",
                "hide": 0,
                "includeAll": True,
                "label": "Service",
                "multi": True,
                "name": "service",
                "query": {
                    "query": "label_values(veil_http_requests_total, service)",
                    "refId": "Prometheus-service",
                },
                "refresh": 2,
                "sort": 1,
                "type": "query",
            }
        ],
    )
    svc = 'service=~"$service"'
    y = 0
    panels = [row(100, "Scrape Health", y)]
    y += 1
    panels += [
        health_stat(2, "veil-api", 'up{job="veil-api"}', 0, y, 4),
        health_stat(3, "veil-mcp", 'up{job="veil-mcp"}', 4, y, 4),
        kpi_stat(
            4,
            "Total RPS",
            f'sum(rate(veil_http_requests_total{{{svc}}}{RI})) or vector(0)',
            8,
            y,
            8,
            unit="ops",
            decimals=2,
            description="Aggregate HTTP request rate across selected services.",
            thresholds=[{"color": C_BLUE, "value": None}],
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
            "p95 Latency by Service",
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
            "5xx Responses / sec",
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
                    "properties": [{"id": "color", "value": {"fixedColor": C_RED, "mode": "fixed"}}],
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
        "Egregore application logs, distributed traces, and span metrics. RED metrics live on cys-agi SOC Platform.",
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
    health_jobs = [
        ("API", 'up{job="egregore-api"}'),
        ("Tempo", 'up{job="tempo"}'),
        ("Loki", 'up{job="loki"}'),
        ("Prometheus", 'up{job="prometheus"}'),
    ]
    for i, (title, expr) in enumerate(health_jobs):
        panels.append(health_stat(2 + i, title, expr, i * 6, y, 6))
    y += 4
    panels.append(row(110, "Logs (Loki)", y))
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
            "title": "Egregore Application Logs",
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
    panels.append(row(120, "Traces (Tempo)", y))
    y += 1
    panels += [
        {
            "datasource": deepcopy(DS_TEMPO),
            "description": "Recent Egregore distributed traces.",
            "gridPos": {"h": 12, "w": 24, "x": 0, "y": y},
            "id": 31,
            "options": {},
            "title": "Recent Egregore Traces",
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
            "Trace Rate (Span Metrics)",
            [
                prom_target(
                    f"sum(rate(tempo_distributor_spans_received_total{RI}))",
                    "{{service}}",
                )
            ],
            0,
            y + 12,
            24,
            description="Trace span call rate from Prometheus span metrics.",
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
            f"sum(rate(cys_sgr_reasoning_steps_total{RI})) or vector(0)",
            0,
            y,
            8,
            description="SGR reasoning steps processed per second.",
            thresholds=[
                {"color": C_BLUE, "value": None},
                {"color": C_GREEN, "value": 0.01},
            ],
            unit="ops",
            decimals=3,
        ),
        kpi_stat(
            2,
            "Iron Parse Retries / sec",
            f"sum(rate(cys_sgr_iron_parse_retries_total{RI})) or vector(0)",
            8,
            y,
            8,
            description="Iron schema parse retries per second.",
            thresholds=[
                {"color": C_GREEN, "value": None},
                {"color": C_WARN, "value": 0.1},
                {"color": C_RED, "value": 1},
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
                {"color": C_GREEN, "value": None},
                {"color": C_WARN, "value": 5},
                {"color": C_RED, "value": 20},
            ],
        ),
    ]
    y += 4
    panels.append(row(110, "Trends", y))
    y += 1
    panels += [
        timeseries(
            4,
            "SGR Reasoning Steps",
            [prom_target(f"sum(rate(cys_sgr_reasoning_steps_total{RI})) or vector(0)", "reasoning_steps/s")],
            0,
            y,
            12,
            description="Reasoning step throughput over time.",
        ),
        timeseries(
            5,
            "Iron Parse Retries",
            [prom_target(f"sum(rate(cys_sgr_iron_parse_retries_total{RI})) or vector(0)", "retries/s")],
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
        templating=[
            {
                "current": {"selected": True, "text": "All", "value": "$__all"},
                "datasource": deepcopy(DS_PROM),
                "definition": 'label_values(up{job="node-exporter"}, instance)',
                "hide": 0,
                "includeAll": True,
                "label": "Instance",
                "multi": True,
                "name": "instance",
                "query": {
                    "query": 'label_values(up{job="node-exporter"}, instance)',
                    "refId": "Prometheus-instance",
                },
                "refresh": 2,
                "sort": 1,
                "type": "query",
            }
        ],
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
                {"color": C_RED, "value": None},
                {"color": C_WARN, "value": 10737418240},
                {"color": C_GREEN, "value": 53687091200},
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
                {"color": C_RED, "value": None},
                {"color": C_WARN, "value": 2147483648},
                {"color": C_GREEN, "value": 8589934592},
            ],
            graph_mode="none",
        ),
        gauge_panel(
            3,
            "CPU Usage",
            f'100 * (1 - avg(rate(node_cpu_seconds_total{{mode="idle",{inst}}}{RI})))',
            12,
            y,
            6,
            unit="percent",
            max_val=100,
            description="Average CPU utilization.",
            thresholds=[
                {"color": C_GREEN, "value": None},
                {"color": C_WARN, "value": 70},
                {"color": C_RED, "value": 90},
            ],
        ),
        gauge_panel(
            4,
            "Load (1m)",
            f'max(node_load1{{{inst}}}) or vector(0)',
            18,
            y,
            6,
            unit="short",
            max_val=16,
            description="1-minute load average.",
            thresholds=[
                {"color": C_GREEN, "value": None},
                {"color": C_WARN, "value": 4},
                {"color": C_RED, "value": 8},
            ],
        ),
    ]
    y += 4
    panels.append(row(110, "CPU & Memory", y))
    y += 1
    panels += [
        timeseries(
            5,
            "CPU Usage (%)",
            [
                prom_target(
                    f'100 * (1 - avg(rate(node_cpu_seconds_total{{mode="idle",{inst}}}{RI})))',
                    "cpu",
                )
            ],
            0,
            y,
            12,
            unit="percent",
            description="CPU utilization over time.",
        ),
        timeseries(
            6,
            "Memory Available",
            [prom_target(f"min(node_memory_MemAvailable_bytes{{{inst}}})", "mem_avail")],
            12,
            y,
            12,
            unit="bytes",
            description="Available memory over time.",
        ),
    ]
    y += 8
    panels.append(row(120, "Storage", y))
    y += 1
    panels.append(
        timeseries(
            7,
            "Disk Usage by Mountpoint (%)",
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
        templating=[
            {
                "current": {"selected": True, "text": "All", "value": "$__all"},
                "datasource": deepcopy(DS_PROM),
                "definition": "label_values(kube_pod_info, namespace)",
                "hide": 0,
                "includeAll": True,
                "label": "Namespace",
                "multi": True,
                "name": "namespace",
                "query": {
                    "query": "label_values(kube_pod_info, namespace)",
                    "refId": "Prometheus-namespace",
                },
                "refresh": 2,
                "sort": 1,
                "type": "query",
            }
        ],
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
                {"color": C_RED, "value": None},
                {"color": C_WARN, "value": 1},
                {"color": C_GREEN, "value": 2},
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
            thresholds=[{"color": C_BLUE, "value": None}],
            graph_mode="none",
        ),
        gauge_panel(
            3,
            "Pods Not Ready",
            f'sum(kube_pod_status_phase{{phase=~"Pending|Failed|Unknown",{ns}}}) or vector(0)',
            12,
            y,
            6,
            max_val=20,
            description="Pods not in Running or Succeeded phase.",
            thresholds=[
                {"color": C_GREEN, "value": None},
                {"color": C_WARN, "value": 1},
                {"color": C_RED, "value": 5},
            ],
        ),
        kpi_stat(
            4,
            "Restarts / sec",
            f"sum(rate(kube_pod_container_status_restarts_total{{{ns}}}{RI})) or vector(0)",
            18,
            y,
            6,
            description="Container restart rate.",
            thresholds=[
                {"color": C_GREEN, "value": None},
                {"color": C_WARN, "value": 0.1},
                {"color": C_RED, "value": 1},
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
            [
                prom_target(
                    f"sum by (phase) (kube_pod_status_phase{{{ns}}})",
                    "{{phase}}",
                )
            ],
            0,
            y,
            12,
            unit="short",
            description="Pod count grouped by phase.",
        ),
        timeseries(
            6,
            "Container Restarts / sec",
            [
                prom_target(
                    f"sum(rate(kube_pod_container_status_restarts_total{{{ns}}}{RI})) or vector(0)",
                    "restarts/s",
                )
            ],
            12,
            y,
            12,
            description="Container restart rate over time.",
        ),
    ]
    d["panels"] = panels
    return d


def patch_egregore_cys_agi(path: Path) -> None:
    data = json.loads(path.read_text())
    data.pop("id", None)
    data["title"] = "cys-agi — SOC Platform"
    data["description"] = (
        "cys-agi SOC platform metrics: workers, tools, security, RAG, cost, and trust."
    )
    data["style"] = "dark"
    data["annotations"] = {"list": []}
    data["links"] = [
        dash_link("CXado Overview", "cxado-overview"),
        dash_link("Egregore Logs & Traces", "egregore-observability"),
        dash_link("SGR Reasoning", "egregore-sgr"),
    ]

    color_map = {"red": C_RED, "green": C_GREEN, "yellow": C_WARN, "orange": C_WARN}

    def fix_colors(obj):
        if isinstance(obj, dict):
            for k, v in list(obj.items()):
                if k == "color" and isinstance(v, str) and v in color_map:
                    obj[k] = color_map[v]
                else:
                    fix_colors(v)
        elif isinstance(obj, list):
            for item in obj:
                if isinstance(item, dict) and isinstance(item.get("color"), str) and item["color"] in color_map:
                    item["color"] = color_map[item["color"]]
                fix_colors(item)

    fix_colors(data)

    # Rebuild scrape row: API, Prometheus, Tempo, Loki only (4x6)
    scrape_jobs = [
        (101, "API", 'up{job="egregore-api"}', 0),
        (103, "Prometheus", 'up{job="prometheus"}', 6),
        (104, "Tempo", 'up{job="tempo"}', 12),
        (106, "Loki", 'up{job="loki"}', 18),
    ]
    new_scrape = [row(100, "Scrape Targets", 0)]
    for pid, title, expr, x in scrape_jobs:
        new_scrape.append(health_stat(pid, title, expr, x, 1, 6))

    # Replace panels until platform overview row
    rest = []
    found_platform = False
    for p in data["panels"]:
        if p.get("id") == 110:
            found_platform = True
        if found_platform:
            rest.append(p)
    if not found_platform:
        rest = [p for p in data["panels"] if p.get("type") != "row" or p.get("id", 0) >= 110]

    data["panels"] = new_scrape + rest

    persona_filter = 'persona=~"$persona"'
    persona_metrics = [
        "cys_worker_job_duration_seconds_bucket",
        "cys_worker_job_duration_seconds_count",
        "cys_job_tokens_total",
        "cys_job_cost_usd",
        "cys_agent_trust_score",
    ]

    def wire_persona(expr: str) -> str:
        if (
            " or vector(0)" not in expr
            and "rate(" in expr
            and " by (" not in expr
            and "histogram_quantile" not in expr
        ):
            if expr.endswith(")"):
                expr = re.sub(r"\)(\s*/)", r") or vector(0)\1", expr, count=1)
            elif expr.endswith("])"):
                expr = expr[:-1] + " or vector(0)]"
        expr = expr.replace("[5m]", RI)
        if "persona=~" in expr:
            return expr
        for metric in persona_metrics:
            if metric not in expr:
                continue
            if f"{metric}[" in expr:
                expr = expr.replace(f"{metric}[", f'{metric}{{{persona_filter}}}[')
            elif metric in expr:
                expr = expr.replace(metric, f"{metric}{{{persona_filter}}}", 1)
        return expr

    def patch_panel(panel: dict):
        if panel.get("type") == "row":
            panel["collapsed"] = False
            if panel.get("title") == "Scrape targets":
                panel["title"] = "Scrape Targets"
            return
        if panel.get("type") == "timeseries":
            fc = panel.setdefault("fieldConfig", {"defaults": {}, "overrides": []})
            defaults = fc.setdefault("defaults", {})
            defaults.setdefault("color", {"mode": "palette-classic"})
            custom = defaults.setdefault("custom", {})
            for k, v in TS_CUSTOM.items():
                custom.setdefault(k, v)
            panel["options"] = {**deepcopy(TS_OPTIONS), **panel.get("options", {})}
        if panel.get("type") == "stat" and panel.get("options", {}).get("colorMode") == "value":
            panel.setdefault("options", {})["justifyMode"] = "center"
        for t in panel.get("targets", []):
            if "expr" in t:
                t["expr"] = wire_persona(t["expr"])
                t.setdefault("refId", "A")
                t.setdefault("range", True)
                t.setdefault("datasource", deepcopy(DS_PROM))

    for p in data["panels"]:
        patch_panel(p)

    path.write_text(json.dumps(data, indent=2) + "\n")


def main() -> None:
    builders = {
        ROOT / "cxado/cxado-overview.json": build_cxado_overview,
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
    patch_egregore_cys_agi(ROOT / "egregore/egregore-cys-agi.json")
    print(f"patched {ROOT / 'egregore/egregore-cys-agi.json'}")


if __name__ == "__main__":
    main()
