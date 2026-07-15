# cxado documentation guide

How documentation is organized in the meta-repo and submodules. **Link instead of copy-paste.**

## SSOT hierarchy

| Layer | File | Holds | Does not hold |
|-------|------|-------|---------------|
| **This guide** | [DOCUMENTATION.md](DOCUMENTATION.md) | Rules, legacy map, PR discipline | Runbooks |
| **Catalog** | [ecosystem-map.md](ecosystem-map.md) | Repos, roles, stack, data flows | Deploy steps |
| **Deploy** | [deploy/nexus-egregore-loop.md](deploy/nexus-egregore-loop.md), [nexus-veil-loop.md](deploy/nexus-veil-loop.md), [nexus-npm-go-proxy-setup.md](deploy/nexus-npm-go-proxy-setup.md) | Kaniko/Nexus P30 loops | Quick start |
| **Ports** | [deploy/ports.md](../deploy/ports.md) | Port SSOT | — |
| **Local artifacts** | [deploy/.local/README.md](../deploy/.local/README.md) | k3s deploy logs, baselines (gitignored) | — |
| **Contracts** | [shared/contracts/README.md](../shared/contracts/README.md) | Wire schemas (`engage.events`) | Integration prose |
| **Integrations** | [integration/README.md](integration/README.md) | Wiring table | Architecture essays |
| **Domains** | [domains/README.md](domains/README.md) | Tabula, Hexenhammer umbrellas | Per-product runbooks |
| **Agents** | [AGENTS.md](../AGENTS.md) | MCP routing, submodule paths | Deploy loops |
| **GH metadata** | [github/repo-catalog.yaml](github/repo-catalog.yaml) | GitHub descriptions SSOT | — |
| **Archive** | [archive/](archive/) | Superseded masterplans | — |

Per-project: `README.md` (one-liner + verify) → `docs/README.md` (index) → `AGENTS.md` (workflow overlay only).

## Legacy name map

| Legacy | Canonical |
|--------|-----------|
| `cys-agi` (repo) | `projects/egregore` |
| `ci-cd-template` / `ci-cd_template` | `projects/fabrica` |
| engage pentest layer | `projects/veneno` |
| hexenhammer / tabula / fstec / asoc-api | **Out of scope** — `~/Desktop/` |
| cxado-agent-rules / cxado-skills / cxado-gui | merged into `shared/*` in cxado |
| cxado-references (repo) | `shared/references/` — **gitignored**, local only |

**Intentional legacy (do not rename in docs/code):** Grafana uid `egregore-cys-agi`, metric prefix `cys_*`, product alias `cys-agi` in egregore `agents/manifest.yaml`, Python package `cys_core`.

## Git remotes

| Remote | When |
|--------|------|
| `origin` (GitHub) | **Always** — default dev upstream |
| `gitlab` (corp) | **Never persistent** — only during `./scripts/gitlab/sync-monorepo-to-gitlab.sh` |

Normalize after clone or drift: `./scripts/gitlab/setup-github-remotes.sh`

## Workspace (Cursor / VS Code)

Open **`cxado.code-workspace`** (File → Open Workspace from File) — not only the root folder.

Submodule repos (veil, veneno, egregore, …) need **embedded** `.git` directories for reliable Cursor SCM. If a submodule still uses a `gitdir:` file, run:

```bash
./scripts/embed-submodule-git.sh projects/veil projects/veneno
```

Then **Developer: Reload Window**.

Workspace settings: `git.detectSubmodules: false`, `git.autoRepositoryDetection: false` (explicit `git.scanRepositories` only), `git.openRepositoryInParentFolders: never`. `shared/*` hubs are **in-tree** — not separate SCM repos; `shared/references` is gitignored local corpora.

Core Cursor rules: `shared/agent-rules/core/` — committed symlinks in [`.cursor/rules/`](../.cursor/rules/). No `make rules-link` into submodules.

## PR discipline

- ≤5 files per doc PR (except archive move = 2–3 files).
- Submodule doc change: commit in submodule → `git push origin main` → bump pointer in meta-repo.

## Submodule bump checklist

```bash
cd projects/<name> && git push origin main
cd ../.. && git add projects/<name> && git commit -m "chore(submodules): bump <name> for docs"
```

## GitHub descriptions

SSOT: [github/repo-catalog.yaml](github/repo-catalog.yaml). Sync:

```bash
make sync-github-descriptions          # from meta-repo root
make sync-github-descriptions DRY_RUN=1
```

Requires `gh` auth with repo Administration scope.

## Doc verification

```bash
./scripts/docs/verify-doc-links.sh
```
