.PHONY: bootstrap help

help:
	@echo "Targets:"
	@echo "  bootstrap  Initialize and update git submodules"

bootstrap:
	@./scripts/bootstrap.sh
