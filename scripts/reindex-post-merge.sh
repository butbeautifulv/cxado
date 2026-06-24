#!/usr/bin/env bash
# Re-index cxado for codebase-memory-mcp AFTER a submodule PR is merged.
# Do NOT run while another agent has unmerged changes in that submodule.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="home-bbv-Desktop-cys_framework"
SCOPE="${1:-all}"

echo "=== codebase-memory re-index (post-merge) ==="
echo "Repo:  $ROOT"
echo "Scope: $SCOPE"
echo ""
echo "Call via codebase-memory-mcp (Cursor agent or MCP client):"
echo ""
if [[ "$SCOPE" == "all" ]]; then
  cat <<EOF
  index_repository(
    repo_path="$ROOT",
    mode="full",
    persistence=true
  )
EOF
else
  cat <<EOF
  # 1. Check health first:
  index_status(project="$PROJECT_ID")

  # 2. Full re-index (moderate does not reliably scope to one submodule):
  index_repository(
    repo_path="$ROOT",
    mode="full",
    persistence=true
  )

  # 3. Verify scoped search works, e.g. for $SCOPE:
  search_code(
    pattern="<symbol>",
    project="$PROJECT_ID",
    path_filter="projects/$SCOPE"
  )
EOF
fi
echo ""
echo "Artifact: $ROOT/.codebase-memory/graph.db.zst"
echo "Skip if another agent is still editing projects/$SCOPE on an open branch."
