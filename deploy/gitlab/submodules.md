# Submodules: GitHub (dev) vs GitLab (corp)

## Two remotes, one laptop

| Remote | URL | When present locally |
|--------|-----|----------------------|
| `origin` | `github.com/butbeautifulv/*` | **Always** — default dev upstream |
| `gitlab` | `gitlab.svo.aero/av.popov/*` | **Never by default** — added only during corp sync scripts |

`.gitmodules` on `origin/main` uses GitHub URLs. Corp tree on GitLab uses `.gitmodules.gitlab` (overlay commit via sync).

Normalize after clone or if remotes drifted:

```bash
./scripts/gitlab/setup-github-remotes.sh
```

## Bootstrap all mirrors (one-time)

Creates every project under `av.popov/*` from `.gitmodules.gitlab` (including nested, e.g. `tabula/fstec`) and pushes:

```bash
./scripts/gitlab/bootstrap-gitlab-mirrors.sh
```

Nested: `projects/tabula/.gitmodules.gitlab` → `av.popov/fstec`. Parent `tabula` push applies GitLab URLs overlay (like monorepo sync).

Re-run safe. API calls go via P30 (`CXADO_OFFLINE_SSH_HOST`).

## Daily workflow (laptop)

```bash
# 1. Dev as usual — commit on main, submodules on GitHub URLs
git push origin main
./scripts/gitlab/push-github.sh          # same as above

# 2. When corp needs an update — one command
./scripts/gitlab/sync-monorepo-to-gitlab.sh
```

`sync-monorepo-to-gitlab.sh`:

1. Pushes each submodule to `gitlab.svo.aero/av.popov/<repo>`
2. Adds one overlay commit with `.gitmodules.gitlab` → pushes to `gitlab/main`
3. Restores local `.gitmodules` (GitHub) — **nothing breaks for GitHub**

Options:

```bash
./scripts/gitlab/sync-monorepo-to-gitlab.sh --only projects/egregore,projects/veil
./scripts/gitlab/sync-monorepo-to-gitlab.sh --skip-submodules   # monorepo pointer only
./scripts/gitlab/sync-monorepo-to-gitlab.sh --dry-run
```

## Files

| File | Purpose |
|------|---------|
| `.gitmodules` | GitHub URLs — **committed on `origin/main`** |
| `.gitmodules.github` | Same — restore template if sync touched working tree |
| `.gitmodules.gitlab` | GitLab URLs — template for corp sync commit |
| `scripts/gitlab/setup-github-remotes.sh` | **Local only** — origin=GitHub, remove gitlab remote |
| `scripts/gitlab/sync-monorepo-to-gitlab.sh` | Push corp copy |
| `scripts/gitlab/push-github.sh` | Push to GitHub only |
| `scripts/gitlab/push-submodule-mirror.sh` | Push one submodule or `--all` |

## CI on P30

After sync, GitLab `main` has GitLab URLs in `.gitmodules`. Runner does **not** reach GitHub.

`ci-submodule-init.sh` still blocks `github.com/butbeautifulv` as belt-and-suspenders.

Default fetch: `CI_SUBMODULES=projects/egregore` (extend when veil/MCPs join pipeline).

## Mirror one submodule manually

```bash
git submodule update --init projects/egregore
./scripts/gitlab/push-submodule-mirror.sh projects/egregore
./scripts/gitlab/push-submodule-mirror.sh --all   # all initialized submodules
```

Creates GitLab project via API if `GITLAB_PAT_RUNNER` is in `deploy/.secrets/cxado-k3s.env`.

## Phase plan (which mirrors matter)

| Phase | Repos |
|-------|-------|
| **Now** | `projects/egregore` |
| **Next** | `projects/veil` |
| **Nested** | `projects/tabula/fstec` (submodule inside tabula — mirrored as `av.popov/fstec`) |
| **As needed** | `projects/veneno`, MCP repos |
| **Not in workspace** | [fish](https://github.com/butbeautifulv/fish) — archive donor for hexenhammer, **no submodule** |
| **In meta-repo** | `shared/skills`, `shared/agent-rules`, `shared/gui` |
| **Local only (gitignored)** | `shared/references/` |
| **Optional** | `projects/fabrica`, `projects/tabula`, … |

## GitLab pull mirror (alternative)

Admin can configure **Pull mirror** on each GitLab project — only if GitLab server can reach GitHub (often blocked in corp). Manual `sync-monorepo-to-gitlab.sh` from laptop is the default.
