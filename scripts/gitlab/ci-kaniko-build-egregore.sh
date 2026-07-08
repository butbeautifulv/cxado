#!/usr/bin/env bash
# Build cxado/egregore via in-cluster Kaniko Job on P30 k3s, push to Nexus, distribute to nodes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

TAG="${CXADO_IMAGE_TAG:-${CI_COMMIT_SHORT_SHA:-offline-$(date +%Y%m%d)}}"
BUILD_ID="${CI_PIPELINE_ID:-local}-${TAG}"
JOB_NAME="kaniko-egregore-${BUILD_ID}"
NS_BUILD="${KANIKO_NS:-cxado-build}"
KANIKO_BUILD_DIR="${KANIKO_BUILD_DIR:-/var/lib/cxado/kaniko-build}"
WORKSPACE="${KANIKO_BUILD_DIR}/${BUILD_ID}"

NEXUS_DOCKER_REGISTRY="${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}"
NEXUS_CXADO_REPO="${NEXUS_CXADO_DOCKER_REPO:-cxado-docker}"
DEST_IMAGE="${NEXUS_DOCKER_REGISTRY}/${NEXUS_CXADO_REPO}/egregore:${TAG}"
LOCAL_IMAGE="docker.io/cxado/egregore:${TAG}"

NEXUS_USER="${NEXUS_USER:-${NEXUS_REPO_USER:-}}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-${NEXUS_REPO_PASSWORD:-}}"
NEXUS_PYPI_HOST="${NEXUS_PYPI_HOST:-nexus.svo.aero:8443}"
NEXUS_PYPI_REPO="${NEXUS_PYPI_REPO:-srsips-pypi}"

DOCKERFILE="${ROOT}/projects/egregore/Dockerfile.corp"
CONTEXT_SRC="${ROOT}/projects/egregore"
JOB_MANIFEST="/tmp/kaniko-job-${BUILD_ID}.yaml"

export KUBECONFIG="${KUBECONFIG:-/home/bbv/.kube/config}"
KCTL="k3s kubectl"

log() { printf '[ci-kaniko-build-egregore] %s\n' "$*"; }

sudo_run() {
  if [[ -n "${CXADO_OFFLINE_SUDO_PW:-}" ]]; then
    printf '%s\n' "${CXADO_OFFLINE_SUDO_PW}" | sudo -S -p "" "$@"
  else
    sudo "$@"
  fi
}

resolve_kaniko_image() {
  if [[ -n "${KANIKO_EXECUTOR_IMAGE:-}" ]]; then
    echo "${KANIKO_EXECUTOR_IMAGE}"
    return
  fi
  if sudo_run k3s ctr images ls 2>/dev/null | grep -q 'kaniko-executor'; then
    echo "${NEXUS_DOCKER_REGISTRY}/${NEXUS_CXADO_REPO}/kaniko-executor:v1.23.2"
  else
    echo "gcr.io/kaniko-project/executor:v1.23.2"
  fi
}

KANIKO_IMAGE="$(resolve_kaniko_image)"

if [[ ! -f "${DOCKERFILE}" ]]; then
  echo "missing ${DOCKERFILE} — run ci-submodule-init.sh first" >&2
  exit 2
fi
if [[ -z "${NEXUS_USER}" || -z "${NEXUS_PASSWORD}" ]]; then
  echo "missing NEXUS_USER / NEXUS_PASSWORD CI variables" >&2
  exit 2
fi

log "prepare workspace ${WORKSPACE}"
sudo_run rm -rf "${WORKSPACE}"
sudo_run mkdir -p "${WORKSPACE}"
sudo_run cp -a "${CONTEXT_SRC}/." "${WORKSPACE}/"
sudo_run cp "${DOCKERFILE}" "${WORKSPACE}/Dockerfile"
sudo_run chmod -R a+rX "${WORKSPACE}"

log "ensure kaniko bootstrap"
"${ROOT}/scripts/k8s/kaniko-bootstrap.sh"

log "submit Job ${JOB_NAME} -> ${DEST_IMAGE}"
cat >"${JOB_MANIFEST}" <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: ${NS_BUILD}
  labels:
    app: kaniko-egregore
    cxado.git/tag: "${TAG}"
spec:
  ttlSecondsAfterFinished: 3600
  backoffLimit: 0
  template:
    metadata:
      labels:
        app: kaniko-egregore
    spec:
      restartPolicy: Never
      serviceAccountName: kaniko-builder
      nodeSelector:
        node-role.kubernetes.io/control-plane: "true"
      containers:
        - name: kaniko
          image: ${KANIKO_IMAGE}
          imagePullPolicy: IfNotPresent
          args:
            - --dockerfile=Dockerfile
            - --context=dir:///workspace
            - --destination=${DEST_IMAGE}
            - --build-arg=NEXUS_REGISTRY=${NEXUS_DOCKER_REGISTRY}
            - --build-arg=NEXUS_PYPI_HOST=${NEXUS_PYPI_HOST}
            - --build-arg=NEXUS_PYPI_REPO=${NEXUS_PYPI_REPO}
            - --build-arg=NEXUS_USER=${NEXUS_USER}
            - --build-arg=NEXUS_PASSWORD=${NEXUS_PASSWORD}
            - --registry-certificate=${NEXUS_DOCKER_REGISTRY},/certs/ca.crt
            - --snapshot-mode=redo
            - --log-format=text
          volumeMounts:
            - name: workspace
              mountPath: /workspace
            - name: docker-config
              mountPath: /kaniko/.docker
            - name: nexus-ca
              mountPath: /certs
              readOnly: true
      volumes:
        - name: workspace
          hostPath:
            path: ${WORKSPACE}
            type: Directory
        - name: docker-config
          secret:
            secretName: nexus-registry
            items:
              - key: .dockerconfigjson
                path: config.json
        - name: nexus-ca
          secret:
            secretName: nexus-ca-cert
EOF

${KCTL} -n "${NS_BUILD}" delete job "${JOB_NAME}" --ignore-not-found
${KCTL} apply -f "${JOB_MANIFEST}"

log "wait for Job completion (timeout 45m)"
if ! ${KCTL} -n "${NS_BUILD}" wait --for=condition=complete "job/${JOB_NAME}" --timeout=2700s; then
  log "Job failed — logs:"
  ${KCTL} -n "${NS_BUILD}" logs "job/${JOB_NAME}" --all-containers=true || true
  exit 1
fi

log "retag for helm (docker.io/cxado/egregore:${TAG})"
OUT_TAR="/tmp/cxado_egregore_${TAG}.tar"
if sudo_run k3s ctr images ls | grep -q "${DEST_IMAGE}"; then
  log "image already in containerd: ${DEST_IMAGE}"
else
  log "ctr pull ${DEST_IMAGE}"
  sudo_run k3s ctr images pull --user "${NEXUS_USER}:${NEXUS_PASSWORD}" "${DEST_IMAGE}"
fi
sudo_run k3s ctr images tag "${DEST_IMAGE}" "${LOCAL_IMAGE}"
sudo_run k3s ctr images export "${OUT_TAR}" "${LOCAL_IMAGE}"

log "distribute to cluster nodes"
"${ROOT}/scripts/k8s/k3s-distribute-image.sh" "${OUT_TAR}"

sudo_run rm -rf "${WORKSPACE}"
${KCTL} -n "${NS_BUILD}" delete job "${JOB_NAME}" --ignore-not-found

mkdir -p "${ROOT}/.ci"
echo "${TAG}" > "${ROOT}/.ci/image-tag"
log "done tag=${TAG} dest=${DEST_IMAGE}"
