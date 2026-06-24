.PHONY: bootstrap skills-install refs-link rules-link help

help:
	@echo "Targets:"
	@echo "  bootstrap       Initialize and update git submodules"
	@echo "  skills-install  Symlink cxado-skills into ~/.cursor/skills/"
	@echo "  refs-link       Symlink shared/references into project refs/"
	@echo "  rules-link      Symlink shared/agent-rules core into project rules/"

bootstrap:
	@./scripts/bootstrap.sh

skills-install:
	@./scripts/install-skills.sh

refs-link:
	@./scripts/link-references.sh

rules-link:
	@./scripts/link-agent-rules.sh
