#!/usr/bin/env python3
"""Minimal GPU Prometheus exporter on :9400 when DCGM-in-Docker cannot access NVML.

Uses host nvidia-smi; exposes DCGM-compatible metric names for existing dashboards.
Run on phy-gpu-host01: systemctl enable --now gpu-metrics-exporter.service
"""
from __future__ import annotations

import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

INSTANCE = "phy-gpu-host01"
PORT = 9400


def collect() -> str:
    out = subprocess.check_output(
        [
            "nvidia-smi",
            "--query-gpu=index,utilization.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits",
        ],
        text=True,
    ).strip().splitlines()
    lines = [
        "# HELP DCGM_FI_DEV_GPU_UTIL GPU utilization percent (nvidia-smi fallback)",
        "# TYPE DCGM_FI_DEV_GPU_UTIL gauge",
        "# HELP DCGM_FI_DEV_FB_USED Framebuffer used MiB",
        "# TYPE DCGM_FI_DEV_FB_USED gauge",
        "# HELP DCGM_FI_DEV_FB_FREE Framebuffer free MiB",
        "# TYPE DCGM_FI_DEV_FB_FREE gauge",
    ]
    for row in out:
        gpu, util, used, total = [x.strip() for x in row.split(",")]
        free = float(total) - float(used)
        labels = 'gpu="{}",instance="{}"'.format(gpu, INSTANCE)
        lines.append("DCGM_FI_DEV_GPU_UTIL{{{}}} {}".format(labels, util))
        lines.append("DCGM_FI_DEV_FB_USED{{{}}} {}".format(labels, used))
        lines.append("DCGM_FI_DEV_FB_FREE{{{}}} {}".format(labels, free))
    return "\n".join(lines) + "\n"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path not in ("/metrics", "/"):
            self.send_response(404)
            self.end_headers()
            return
        body = collect().encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args: object) -> None:
        return


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
