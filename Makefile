.PHONY: bootstrap skills-install skills-link refs-cleanup gui-link auth-broker-test test-contracts \
	cxado-up cxado-up-lite cxado-up-minimal cxado-up-veil cxado-up-siem-mcp cxado-up-tenable-mcp cxado-up-defectdojo-mcp siem-mcp-scrape-docs cxado-down cxado-status cxado-obs-reload cxado-validate-grafana \
	cxado-local-e2e \
	cxado-kind-up cxado-kind-down cxado-k8s-build-images cxado-tf-init cxado-tf-apply cxado-tf-destroy \
	cxado-k8s-up cxado-k8s-status cxado-k8s-smoke cxado-graph-bootstrap cxado-tf-validate agent-skills-install \
	k3s-baseline k3s-baseline-critical k3s-cluster-snapshot \
	k3s-validation-gate k3s-validation-infra \
	egregore-typecheck egregore-typecheck-tests-core \
	sync-github-descriptions verify-doc-links \
	wshobson-skills-install help

help:
	@echo "Targets:"
	@echo "  bootstrap       Initialize submodules + skills/gui links + cleanup legacy symlinks"
	@echo "  cxado-up        Full stack: veil + egregore infra + obs (Tempo, Qdrant)"
	@echo "  cxado-up-lite   Lite profile: no Tempo, 1 worker; includes Qdrant + Langfuse"
	@echo "  cxado-up-minimal  Agents-only: veil-lite + postgres+redis+langfuse+grafana (no kafka/qdrant)"
	@echo "  cxado-up-veil     Veil graph-only (neo4j+api+mcp) on cxado-net"
	@echo "  cxado-up-siem-mcp MaxPatrol SIEM MCP HTTP on :8094 (host process)"
	@echo "  cxado-up-tenable-mcp Nessus MCP HTTP on :8095 (host process)"
	@echo "  cxado-up-defectdojo-mcp DefectDojo MCP HTTP on :8096 (host process)"
	@echo "  cxado-smoke-tenable-mcp  Nessus MCP health + tools/list smoke (:8095)"
	@echo "  cxado-smoke-defectdojo-mcp  DefectDojo MCP health + tools/list smoke (:8096)"
	@echo "  siem-mcp-scrape-docs  Refresh maxpatrol-siem-mcp/docs/API.md from PT help 27.2"
	@echo "  cxado-smoke-veil-mcp  Veil MCP health + tools/list smoke (:8091)"
	@echo "  cxado-up-langfuse  cxado-up + Langfuse (:3001)"
	@echo "  cxado-down      Stop obs + egregore infra (keeps veil by default)"
	@echo "  cxado-status    Health checks for cxado-default"
	@echo "  cxado-validate-grafana  Prometheus datasource + egregore-api target health"
	@echo "  cxado-local-e2e     POST investigation smoke against localhost:8080"
	@echo "  cxado-kind-up     Create kind cluster + ingress (cxado profile)"
	@echo "  cxado-k8s-up      kind-up + build images + terraform apply"
	@echo "  cxado-k8s-status  kubectl + curl health checks"
	@echo "  cxado-k8s-smoke   Post-deploy smoke tests"
	@echo "  cxado-graph-bootstrap  One-shot Neo4j seed (GRAPH_PACK_SKIP=0)"
	@echo "  cxado-tf-validate terraform validate in deploy/terraform/cxado-kind"
	@echo "  k3s-baseline           Collect full k3s Prometheus baseline snapshot"
	@echo "  k3s-baseline-critical  Collect critical-query subset only"
	@echo "  k3s-validation-gate     Phase 9 full validation (infra + scenarios + report)"
	@echo "  k3s-validation-infra    Phase 9 infra-only gate (fast)"
	@echo "  k3s-cluster-snapshot   SSH kubectl dump for cxado offline cluster"
	@echo "  egregore-typecheck     ty check production paths (egregore)"
	@echo "  egregore-typecheck-tests-core  ty check domain + core flow tests"
	@echo "  skills-link     Symlink shared/skills into project .agents/skills/"
	@echo "  skills-install  Symlink cxado-skills into ~/.cursor/skills/"
	@echo "  refs-cleanup    Remove legacy projects/*/refs symlinks (SSOT: refs/ at meta root)"
	@echo "  gui-link        Symlink shared/gui into project node_modules/@cxado/gui"
	@echo "  agent-skills-install  Fetch docker-expert + grafana-dashboards into .agents/skills/"
	@echo "  wshobson-skills-install  Curated wshobson/agents skills (Python, LLM, k8s, UI, DevSecOps)"
	@echo "  auth-broker-test  Run shared/go/auth-broker unit tests"
	@echo "  test-contracts  Cross-repo engage.events wire contract smoke"

bootstrap:
	@./scripts/bootstrap.sh
	@./scripts/cleanup-legacy-shared-links.sh

skills-link:
	@./scripts/link-skills.sh

skills-install:
	@./scripts/install-skills.sh

refs-cleanup:
	@./scripts/cleanup-refs-symlinks.sh

gui-link:
	@./scripts/link-gui.sh

agent-skills-install:
	@chmod +x scripts/install-agent-skills.sh
	@./scripts/install-agent-skills.sh

wshobson-skills-install:
	@chmod +x scripts/install-wshobson-skills.sh
	@./scripts/install-wshobson-skills.sh

auth-broker-test:
	@cd shared/go/auth-broker && go test ./...

test-contracts:
	@./scripts/test/cross-repo-engage-contract.sh
	@./scripts/test/auth-broker-contract-smoke.sh

cxado-up:
	@chmod +x scripts/cxado-up.sh scripts/cxado-down.sh scripts/cxado-status.sh
	@./scripts/cxado-up.sh

cxado-up-lite:
	@chmod +x scripts/cxado-up.sh scripts/cxado-down.sh scripts/cxado-status.sh
	@CXADO_PROFILE=lite ./scripts/cxado-up.sh

cxado-up-minimal:
	@chmod +x scripts/cxado-up-minimal.sh scripts/cxado-down.sh
	@./scripts/cxado-up-minimal.sh

cxado-up-veil:
	@chmod +x scripts/cxado-up-veil.sh
	@./scripts/cxado-up-veil.sh

cxado-up-siem-mcp:
	@chmod +x scripts/cxado-up-siem-mcp.sh projects/precursor/maxpatrol-siem-mcp/scripts/smoke_mcp.sh
	@./scripts/cxado-up-siem-mcp.sh

cxado-up-tenable-mcp:
	@chmod +x scripts/cxado-up-tenable-mcp.sh projects/precursor/tenable-mcp/scripts/smoke_mcp.sh
	@./scripts/cxado-up-tenable-mcp.sh

cxado-smoke-tenable-mcp:
	@chmod +x projects/precursor/tenable-mcp/scripts/smoke_mcp.sh
	@./projects/precursor/tenable-mcp/scripts/smoke_mcp.sh

cxado-up-defectdojo-mcp:
	@chmod +x scripts/cxado-up-defectdojo-mcp.sh projects/precursor/defectdojo-mcp/scripts/smoke_mcp.sh
	@./scripts/cxado-up-defectdojo-mcp.sh

cxado-smoke-defectdojo-mcp:
	@chmod +x projects/precursor/defectdojo-mcp/scripts/smoke_mcp.sh
	@./projects/precursor/defectdojo-mcp/scripts/smoke_mcp.sh

siem-mcp-scrape-docs:
	@cd projects/precursor/maxpatrol-siem-mcp && uv sync --all-groups && uv run python scripts/scrape_api_docs.py

cxado-smoke-veil-mcp:
	@chmod +x projects/egregore/scripts/smoke_veil_mcp.sh
	@./projects/egregore/scripts/smoke_veil_mcp.sh

cxado-smoke-veil-mcp-k3s:
	@chmod +x projects/egregore/scripts/smoke_veil_mcp.sh
	@CXADO_OFFLINE_SSH_HOST="$(CXADO_OFFLINE_SSH_HOST)" ./projects/egregore/scripts/smoke_veil_mcp.sh

.PHONY: cxado-up-veil cxado-up-siem-mcp cxado-up-tenable-mcp cxado-up-defectdojo-mcp cxado-smoke-veil-mcp cxado-smoke-tenable-mcp cxado-smoke-defectdojo-mcp

cxado-validate-grafana:
	@chmod +x scripts/validate-local-grafana.sh
	@./scripts/validate-local-grafana.sh

cxado-local-e2e:
	@chmod +x scripts/local-e2e-smoke.sh
	@./scripts/local-e2e-smoke.sh

cxado-up-langfuse:
	@chmod +x scripts/cxado-up.sh
	@CXADO_LANGFUSE=1 ./scripts/cxado-up.sh

cxado-up-obs:
	@docker network create cxado-net 2>/dev/null || true
	@docker compose -f deploy/compose/observability.yml up -d

cxado-down:
	@./scripts/cxado-down.sh

cxado-status:
	@./scripts/cxado-status.sh

cxado-obs-reload:
	@curl -fsS -X POST http://localhost:9091/-/reload

cxado-kind-up:
	@chmod +x scripts/k8s/bootstrap-kind.sh
	@./scripts/k8s/bootstrap-kind.sh

cxado-kind-down:
	@chmod +x scripts/k8s/teardown-kind.sh
	@./scripts/k8s/teardown-kind.sh

cxado-k8s-build-images:
	@chmod +x scripts/k8s/build-load-images.sh
	@./scripts/k8s/build-load-images.sh

cxado-tf-init:
	@cd deploy/terraform/cxado-kind && terraform init

cxado-tf-apply:
	@cd deploy/terraform/cxado-kind && terraform apply -auto-approve

cxado-tf-destroy:
	@cd deploy/terraform/cxado-kind && terraform destroy -auto-approve

cxado-k8s-up: cxado-kind-up cxado-k8s-build-images cxado-tf-init cxado-tf-apply

cxado-k8s-status:
	@chmod +x scripts/k8s/k8s-status.sh
	@./scripts/k8s/k8s-status.sh

cxado-k8s-smoke:
	@chmod +x scripts/k8s/smoke-test.sh
	@./scripts/k8s/smoke-test.sh

cxado-graph-bootstrap:
	@GRAPH_PACK_SKIP=0 docker compose -f deploy/compose/veil-graph.yml run --rm graph-bootstrap

cxado-tf-validate:
	@cd deploy/terraform/cxado-kind && terraform init -backend=false && terraform validate

k3s-baseline:
	@chmod +x scripts/k8s/collect-k3s-baseline.sh
	@./scripts/k8s/collect-k3s-baseline.sh

k3s-baseline-critical:
	@chmod +x scripts/k8s/collect-k3s-baseline.sh
	@BASELINE_CRITICAL_ONLY=1 ./scripts/k8s/collect-k3s-baseline.sh

k3s-cluster-snapshot:
	@chmod +x scripts/k8s/collect-k3s-cluster-snapshot.sh
	@./scripts/k8s/collect-k3s-cluster-snapshot.sh

k3s-validation-gate:
	@chmod +x scripts/k8s/run-k3s-validation-gate.sh \
		scripts/k8s/run-validation-scenarios.sh \
		scripts/k8s/generate-k3s-after-report.sh
	@./scripts/k8s/run-k3s-validation-gate.sh

k3s-validation-infra:
	@chmod +x scripts/k8s/run-k3s-validation-gate.sh \
		scripts/k8s/generate-k3s-after-report.sh
	@VALIDATION_SKIP_SCENARIOS=1 VALIDATION_SKIP_OBSERVE=1 VALIDATION_SKIP_BENCHMARK=1 \
		./scripts/k8s/run-k3s-validation-gate.sh

egregore-typecheck:
	cd projects/egregore && uv run ty check src

egregore-typecheck-tests-core:
	cd projects/egregore && uv run ty check tests/domain \
	  tests/application/test_enqueue_worker_jobs.py \
	  tests/application/test_route_and_enqueue.py \
	  tests/application/test_plan_investigation_parallel.py \
	  tests/application/test_plan_investigation_ports.py \
	  tests/application/test_plan_investigation_catalog.py \
	  tests/application/test_bus_loop_guard.py \
	  tests/workers/test_orchestrator.py \
	  tests/workers/test_orchestrator_branches.py \
	  tests/worker/test_sequential_enqueue.py \
	  tests/contracts/test_job_queue_port.py \
	  tests/application/port_fakes.py \
	  tests/application/workers/factory.py

sync-github-descriptions:
	@chmod +x scripts/github/sync-descriptions.sh
	@./scripts/github/sync-descriptions.sh

verify-doc-links:
	@chmod +x scripts/docs/verify-doc-links.sh
	@./scripts/docs/verify-doc-links.sh
