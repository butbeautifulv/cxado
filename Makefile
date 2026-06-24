.PHONY: bootstrap skills-install skills-link refs-link rules-link test-contracts help

help:
	@echo "Targets:"
	@echo "  bootstrap       Initialize and update git submodules"
	@echo "  skills-link     Symlink shared/skills into project .agents/skills/"
	@echo "  skills-install  Symlink cxado-skills into ~/.cursor/skills/"
	@echo "  refs-link       Symlink shared/references into project refs/"
	@echo "  rules-link      Symlink shared/agent-rules core into project rules/"
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

test-contracts:
	@./scripts/test/cross-repo-engage-contract.sh
