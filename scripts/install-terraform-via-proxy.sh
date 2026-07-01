#!/usr/bin/env bash
set -euo pipefail

PROXY_HOST="${PROXY_HOST:-$(gsettings get org.gnome.system.proxy.http host 2>/dev/null | tr -d "'")}"
PROXY_PORT="${PROXY_PORT:-$(gsettings get org.gnome.system.proxy.http port 2>/dev/null)}"
PROXY="${HTTP_PROXY:-http://${PROXY_HOST}:${PROXY_PORT}}"

export http_proxy="$PROXY" https_proxy="$PROXY" HTTP_PROXY="$PROXY" HTTPS_PROXY="$PROXY"

APT_PROXY_OPTS=(
  -o "Acquire::http::Proxy=${PROXY}"
  -o "Acquire::https::Proxy=${PROXY}"
)

TMPKEY="$(mktemp)"
trap 'rm -f "$TMPKEY"' EXIT

echo "Using proxy: $PROXY"
wget -qO "$TMPKEY" https://apt.releases.hashicorp.com/gpg
sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg < "$TMPKEY"

CODENAME="$(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs)"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${CODENAME} main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt "${APT_PROXY_OPTS[@]}" update
sudo apt "${APT_PROXY_OPTS[@]}" install -y terraform
terraform version
