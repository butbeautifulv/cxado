#!/usr/bin/env bash
# Install curated wshobson/agents skills relevant to cxado (egregore, veil, k8s, DevSecOps).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Already present via other installers: grafana-dashboards, fastapi-templates
SKILLS=(
  # Python / FastAPI (egregore core)
  async-python-patterns
  python-testing-patterns
  python-observability
  python-error-handling
  python-configuration
  python-resilience
  python-design-patterns
  python-type-safety
  python-background-jobs
  python-resource-management
  uv-package-manager
  # LLM / RAG / eval (egregore, veil)
  langchain-architecture
  rag-implementation
  llm-evaluation
  prompt-engineering-patterns
  hybrid-search-implementation
  embedding-strategies
  # Observability (Langfuse, Tempo, Prometheus)
  distributed-tracing
  prometheus-configuration
  slo-implementation
  incident-runbook-templates
  postmortem-writing
  # Kubernetes / deploy
  helm-chart-scaffolding
  k8s-manifest-generator
  k8s-security-policies
  gitops-workflow
  # CI/CD / DevSecOps
  github-actions-templates
  deployment-pipeline-design
  secrets-management
  sast-configuration
  # Security platform / RBAC
  auth-implementation-patterns
  stride-analysis-patterns
  security-requirement-extraction
  # Data / API / architecture
  postgresql-table-design
  architecture-decision-records
  openapi-spec-generation
  architecture-patterns
  microservices-patterns
  workflow-orchestration-patterns
  api-design-principles
  # Next.js UI (egregore/ui)
  nextjs-app-router-patterns
  typescript-advanced-types
  javascript-testing-patterns
  tailwind-design-system
  e2e-testing-patterns
  # Engineering quality
  debugging-strategies
  code-review-excellence
  sql-optimization-patterns
  # Docs
  hads
  changelog-automation
)

args=()
for skill in "${SKILLS[@]}"; do
  args+=(-s "$skill")
done

echo "[wshobson] installing ${#SKILLS[@]} curated skills into .agents/skills/"
npx skills add wshobson/agents "${args[@]}" -a cursor -y

echo "[wshobson] done — see skills-lock.json and .agents/skills/"
