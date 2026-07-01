.PHONY: bootstrap skills-install skills-link refs-link rules-link gui-link auth-broker-test test-contracts \
	cxado-up cxado-up-lite cxado-up-obs cxado-up-langfuse cxado-down cxado-status cxado-obs-reload \
	cxado-kind-up cxado-kind-down cxado-k8s-build-images cxado-tf-init cxado-tf-apply cxado-tf-destroy \
	cxado-k8s-up cxado-k8s-status cxado-k8s-smoke cxado-graph-bootstrap cxado-tf-validate agent-skills-install help

help:
	@echo "Targets:"
	@echo "  bootstrap       Initialize and update git submodules"
	@echo "  cxado-up        Full stack: veil + egregore infra + obs (Tempo, Qdrant)"
	@echo "  cxado-up-lite   Lite profile: no Tempo, 1 worker; includes Qdrant + Langfuse"
	@echo "  cxado-up-langfuse  cxado-up + Langfuse (:3001)"
	@echo "  cxado-down      Stop obs + egregore infra (keeps veil by default)"
	@echo "  cxado-status    Health checks for cxado-default"
	@echo "  cxado-obs-reload  Reload Prometheus config"
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
