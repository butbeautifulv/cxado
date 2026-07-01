#!/usr/bin/env bash
# Install agent skills declared in skills-lock.json but missing from .agents/skills/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/.agents/skills"
mkdir -p "$DEST"

fetch_skill() {
  local name="$1" repo="$2" path="$3"
  local dir="$DEST/$name"
  if [[ -f "$dir/SKILL.md" ]]; then
    echo "[skills] $name already present"
    return 0
  fi
  mkdir -p "$dir"
  local url="https://raw.githubusercontent.com/${repo}/main/${path}"
  echo "[skills] fetching $name from $url"
  if curl -fsSL "$url" -o "$dir/SKILL.md"; then
    echo "[skills] installed $name"
  else
    echo "[skills] WARN: failed to fetch $name" >&2
    rmdir "$dir" 2>/dev/null || true
  fi
}

fetch_skill "docker-expert" "sickn33/antigravity-awesome-skills" "skills/docker-expert/SKILL.md"
fetch_skill "grafana-dashboards" "wshobson/agents" "plugins/observability-monitoring/skills/grafana-dashboards/SKILL.md"
