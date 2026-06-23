.PHONY: bootstrap skills-install help

help:
	@echo "Targets:"
	@echo "  bootstrap       Initialize and update git submodules"
	@echo "  skills-install  Symlink cxado-skills into ~/.cursor/skills/"

bootstrap:
	@./scripts/bootstrap.sh

skills-install:
	@./scripts/install-skills.sh
