.PHONY: bootstrap skills-install refs-link help

help:
	@echo "Targets:"
	@echo "  bootstrap       Initialize and update git submodules"
	@echo "  skills-install  Symlink cxado-skills into ~/.cursor/skills/"
	@echo "  refs-link       Symlink shared/references into project refs/"

bootstrap:
	@./scripts/bootstrap.sh

skills-install:
	@./scripts/install-skills.sh

refs-link:
	@./scripts/link-references.sh
