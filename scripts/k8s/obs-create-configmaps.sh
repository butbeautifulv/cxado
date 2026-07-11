#!/usr/bin/env bash
# Create/refresh observability ConfigMaps (prometheus config, grafana provisioning/dashboards).
#
# Usage:
#   ./scripts/k8s/obs-create-configmaps.sh
#
# Remote bundle mode (k3s offline deploy):
#   CXADO_OBS_SRC=/tmp/cxado-obs-bundle ./scripts/k8s/obs-create-configmaps.sh
#
# Veil worker scrape profile (Phase 6):
#   CXADO_VEIL_PROFILE=graph-only   — default; no veil-*-worker scrape jobs
#   CXADO_VEIL_PROFILE=workers-obs  — append prometheus-k3s-veil-workers-scrape.yaml
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NS="${CXADO_OBS_NS:-cxado-obs}"
K3S_CONFIG_FILE="${K3S_CONFIG_FILE:-/dev/null}"
export K3S_CONFIG_FILE
if [[ -z "${KUBECONFIG:-}" && -f "${HOME}/.kube/config" ]]; then
  export KUBECONFIG="${HOME}/.kube/config"
fi
CXADO_VEIL_PROFILE="${CXADO_VEIL_PROFILE:-graph-only}"

kctl() {
  if command -v k3s >/dev/null 2>&1; then
    k3s kubectl "$@"
  else
    kubectl "$@"
  fi
}

if [[ -n "${CXADO_OBS_SRC:-}" ]]; then
  K8S_OBS="${CXADO_OBS_SRC}/k8s"
  OBS="${CXADO_OBS_SRC}/observability"
else
  K8S_OBS="${ROOT}/deploy/k8s/obs-offline"
  OBS="${ROOT}/deploy/observability"
fi

build_prometheus_config() {
  local out="$1"
  python3 - "${K8S_OBS}" "${CXADO_VEIL_PROFILE}" "${out}" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML required: pip install pyyaml") from exc

k8s_obs = Path(sys.argv[1])
profile = sys.argv[2]
out = Path(sys.argv[3])

cfg = yaml.safe_load((k8s_obs / "prometheus-k3s.yml").read_text())
cfg.setdefault("global", {}).setdefault("external_labels", {})["veil_profile"] = profile

if profile == "workers-obs":
    extra = yaml.safe_load(
        (k8s_obs / "prometheus-k3s-veil-workers-scrape.yaml").read_text()
    )
    cfg.setdefault("scrape_configs", []).extend(extra)

out.write_text(yaml.dump(cfg, sort_keys=False, default_flow_style=False))
PY
}

PROM_TMP="$(mktemp)"
trap 'rm -f "${PROM_TMP}"' EXIT
build_prometheus_config "${PROM_TMP}"

kctl get ns "${NS}" >/dev/null 2>&1 || kctl create ns "${NS}"

kctl -n "${NS}" delete configmap prometheus-config >/dev/null 2>&1 || true
kctl -n "${NS}" create configmap prometheus-config \
  --from-file=prometheus.yml="${PROM_TMP}"

kctl -n "${NS}" delete configmap grafana-provisioning >/dev/null 2>&1 || true
kctl -n "${NS}" create configmap grafana-provisioning \
  --from-file=dashboards.yml="${OBS}/grafana/provisioning/dashboards/dashboards.yml" \
  --from-file=datasources.yml="${OBS}/grafana/provisioning/datasources/datasources.yml"

kctl -n "${NS}" delete configmap grafana-dashboards >/dev/null 2>&1 || true
kctl -n "${NS}" create configmap grafana-dashboards \
  --from-file=infra-host.json="${OBS}/grafana/dashboards/infra/infra-host.json" \
  --from-file=infra-k3s.json="${OBS}/grafana/dashboards/infra/infra-k3s.json" \
  --from-file=vllm-monitoring.json="${OBS}/grafana/dashboards/infra/vllm-monitoring.json" \
  --from-file=cxado-overview.json="${OBS}/grafana/dashboards/cxado/cxado-overview.json" \
  --from-file=egregore-cys-agi.json="${OBS}/grafana/dashboards/egregore/egregore-cys-agi.json" \
  --from-file=egregore-observability.json="${OBS}/grafana/dashboards/egregore/egregore-observability.json" \
  --from-file=sgr-reasoning.json="${OBS}/grafana/dashboards/egregore/sgr-reasoning.json" \
  --from-file=veil-graph.json="${OBS}/grafana/dashboards/veil/veil-graph.json" \
  --from-file=veil-observability.json="${OBS}/grafana/dashboards/veil/veil-observability.json"

kctl -n "${NS}" delete configmap prometheus-rules >/dev/null 2>&1 || true
kctl -n "${NS}" create configmap prometheus-rules \
  --from-file=egregore-alerts.yml="${OBS}/prometheus/rules/egregore-alerts.yml" \
  --from-file=veil-alerts.yml="${OBS}/prometheus/rules/veil-alerts.yml" \
  --from-file=gpu-alerts.yml="${OBS}/prometheus/rules/gpu-alerts.yml"

kctl -n "${NS}" delete configmap tempo-config >/dev/null 2>&1 || true
kctl -n "${NS}" create configmap tempo-config \
  --from-file=tempo.yaml="${OBS}/tempo/tempo.yaml"

kctl -n "${NS}" delete configmap loki-config >/dev/null 2>&1 || true
kctl -n "${NS}" create configmap loki-config \
  --from-file=loki.yaml="${OBS}/loki/loki.yaml"

kctl -n "${NS}" delete configmap promtail-config >/dev/null 2>&1 || true
kctl -n "${NS}" create configmap promtail-config \
  --from-file=promtail.yaml="${OBS}/promtail/promtail.yaml"

echo "configmaps refreshed in ${NS} (veil_profile=${CXADO_VEIL_PROFILE})"
