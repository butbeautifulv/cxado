.PHONY: bootstrap skills-install skills-link refs-link rules-link gui-link auth-broker-test test-contracts \
	cxado-up cxado-up-lite cxado-up-minimal cxado-up-veil cxado-up-siem-mcp cxado-up-tenable-mcp cxado-up-defectdojo-mcp siem-mcp-scrape-docs cxado-down cxado-status cxado-obs-reload cxado-validate-grafana \
	cxado-local-e2e \
	cxado-kind-up cxado-kind-down cxado-k8s-build-images cxado-tf-init cxado-tf-apply cxado-tf-destroy \
	cxado-k8s-up cxado-k8s-status cxado-k8s-smoke cxado-graph-bootstrap cxado-tf-validate agent-skills-install \
	wshobson-skills-install help

help:
	@echo "Targets:"
	@echo "  bootstrap       Initialize and update git submodules"
	@echo "  cxado-up        Full stack: veil + egregore infra + obs (Tempo, Qdrant)"
	@echo "  cxado-up-lite   Lite profile: no Tempo, 1 worker; includes Qdrant + Langfuse"
	@echo "  cxado-up-minimal  Agents-only: postgres+redis+langfuse+grafana (no veil/kafka)"
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
	@echo "  skills-link     Symlink shared/skills into project .agents/skills/"
	@echo "  skills-install  Symlink cxado-skills into ~/.cursor/skills/"
	@echo "  refs-link       Symlink shared/references into project refs/"
	@echo "  rules-link      Symlink shared/agent-rules core into project rules/"
	@echo "  gui-link        Symlink shared/gui into project node_modules/@cxado/gui"
	@echo "  agent-skills-install  Fetch docker-expert + grafana-dashboards into .agents/skills/"
	@echo "  wshobson-skills-install  Curated wshobson/agents skills (Python, LLM, k8s, UI, DevSecOps)"
	@echo "  auth-broker-test  Run shared/go/auth-broker unit tests"
	@echo "  test-contracts  Cross-repo engage.events wire contract smoke"

bootstrap:
	@./scripts/bootstrap.sh

skills-link:
	@./scripts/link-skills.sh

skills-install:
	@./scripts/install-skills.sh

refs-link:
	@./scripts/link-references.sh

rules-link:
	@./scripts/link-agent-rules.sh

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
	@chmod +x scripts/cxado-up-siem-mcp.sh projects/maxpatrol-siem-mcp/scripts/smoke_mcp.sh
	@./scripts/cxado-up-siem-mcp.sh

cxado-up-tenable-mcp:
	@chmod +x scripts/cxado-up-tenable-mcp.sh projects/tenable-mcp/scripts/smoke_mcp.sh
	@./scripts/cxado-up-tenable-mcp.sh

cxado-smoke-tenable-mcp:
	@chmod +x projects/tenable-mcp/scripts/smoke_mcp.sh
	@./projects/tenable-mcp/scripts/smoke_mcp.sh

cxado-up-defectdojo-mcp:
	@chmod +x scripts/cxado-up-defectdojo-mcp.sh projects/defectdojo-mcp/scripts/smoke_mcp.sh
	@./scripts/cxado-up-defectdojo-mcp.sh

cxado-smoke-defectdojo-mcp:
	@chmod +x projects/defectdojo-mcp/scripts/smoke_mcp.sh
	@./projects/defectdojo-mcp/scripts/smoke_mcp.sh

siem-mcp-scrape-docs:
	@cd projects/maxpatrol-siem-mcp && uv sync --all-groups && uv run python scripts/scrape_api_docs.py

cxado-smoke-veil-mcp:
	@chmod +x projects/egregore/scripts/smoke_veil_mcp.sh
	@./projects/egregore/scripts/smoke_veil_mcp.sh

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
