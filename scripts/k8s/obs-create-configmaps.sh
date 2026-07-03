#!/usr/bin/env bash
# Create/refresh observability ConfigMaps (prometheus config, grafana provisioning/dashboards).
#
# Usage:
#   ./scripts/k8s/obs-create-configmaps.sh
#
# Remote bundle mode (k3s offline deploy):
#   CXADO_OBS_SRC=/tmp/cxado-obs-bundle ./scripts/k8s/obs-create-configmaps.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NS="${CXADO_OBS_NS:-cxado-obs}"
KUBECTL="${KUBECTL:-kubectl}"

if [[ -n "${CXADO_OBS_SRC:-}" ]]; then
  K8S_OBS="${CXADO_OBS_SRC}/k8s"
  OBS="${CXADO_OBS_SRC}/observability"
else
  K8S_OBS="${ROOT}/deploy/k8s/obs-offline"
  OBS="${ROOT}/deploy/observability"
fi

${KUBECTL} get ns "${NS}" >/dev/null 2>&1 || ${KUBECTL} create ns "${NS}"

${KUBECTL} -n "${NS}" delete configmap prometheus-config >/dev/null 2>&1 || true
${KUBECTL} -n "${NS}" create configmap prometheus-config \
  --from-file=prometheus.yml="${K8S_OBS}/prometheus-k3s.yml"

${KUBECTL} -n "${NS}" delete configmap grafana-provisioning >/dev/null 2>&1 || true
${KUBECTL} -n "${NS}" create configmap grafana-provisioning \
  --from-file=dashboards.yml="${OBS}/grafana/provisioning/dashboards/dashboards.yml" \
  --from-file=datasources.yml="${OBS}/grafana/provisioning/datasources/datasources.yml"

${KUBECTL} -n "${NS}" delete configmap grafana-dashboards >/dev/null 2>&1 || true
${KUBECTL} -n "${NS}" create configmap grafana-dashboards \
  --from-file=infra-host.json="${OBS}/grafana/dashboards/infra/infra-host.json" \
  --from-file=infra-k3s.json="${OBS}/grafana/dashboards/infra/infra-k3s.json" \
  --from-file=vllm-monitoring.json="${OBS}/grafana/dashboards/infra/vllm-monitoring.json" \
  --from-file=cxado-overview.json="${OBS}/grafana/dashboards/cxado/cxado-overview.json" \
  --from-file=egregore-cys-agi.json="${OBS}/grafana/dashboards/egregore/egregore-cys-agi.json" \
  --from-file=egregore-observability.json="${OBS}/grafana/dashboards/egregore/egregore-observability.json" \
  --from-file=sgr-reasoning.json="${OBS}/grafana/dashboards/egregore/sgr-reasoning.json" \
  --from-file=veil-graph.json="${OBS}/grafana/dashboards/veil/veil-graph.json" \
  --from-file=veil-observability.json="${OBS}/grafana/dashboards/veil/veil-observability.json"

${KUBECTL} -n "${NS}" delete configmap prometheus-rules >/dev/null 2>&1 || true
${KUBECTL} -n "${NS}" create configmap prometheus-rules \
  --from-file=egregore-alerts.yml="${OBS}/prometheus/rules/egregore-alerts.yml" \
  --from-file=veil-alerts.yml="${OBS}/prometheus/rules/veil-alerts.yml"

${KUBECTL} -n "${NS}" delete configmap tempo-config >/dev/null 2>&1 || true
${KUBECTL} -n "${NS}" create configmap tempo-config \
  --from-file=tempo.yaml="${OBS}/tempo/tempo.yaml"

${KUBECTL} -n "${NS}" delete configmap loki-config >/dev/null 2>&1 || true
${KUBECTL} -n "${NS}" create configmap loki-config \
  --from-file=loki.yaml="${OBS}/loki/loki.yaml"

${KUBECTL} -n "${NS}" delete configmap promtail-config >/dev/null 2>&1 || true
${KUBECTL} -n "${NS}" create configmap promtail-config \
  --from-file=promtail.yaml="${OBS}/promtail/promtail.yaml"

echo "configmaps refreshed in ${NS}"
