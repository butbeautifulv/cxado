# cxado agent rules (in meta-repo)

Shared **core** Cursor agent rules for the cxado ecosystem.

**SSOT:** `shared/agent-rules/core/*.mdc`

**Cursor:** open `cxado.code-workspace` (or cxado root). Rules load from [`.cursor/rules/`](../../.cursor/rules/) — symlinks to `core/`. No per-project linking; submodules stay independent.

Project-specific overlays stay in each submodule (e.g. `projects/egregore/.agents/rules/project-*.mdc`).

## Core rules

| Rule | Purpose |
|------|---------|
| `karpathy-guidelines.mdc` | Think first, surgical diffs, verifiable DoD |
| `workflow-chain.mdc` | Master plan → branch → implement → critic → merge |
| `parallel-branches.mdc` | One branch per phase, merge discipline |
| `agent-critic.mdc` | Orchestrator review gate |
| `kaizen.mdc` | 5 Whys on failures |
| `agent-documentation.mdc` | Post-merge doc actualization |
| `agent-mcp-tooling.mdc` | MCP-first: codebase-memory, Serena, Context7 |
