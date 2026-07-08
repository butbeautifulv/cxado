# Submodules: GitHub (dev) vs GitLab (corp)

## Two remotes, one laptop

| Remote | URL | `.gitmodules` | Who uses it |
|--------|-----|---------------|-------------|
| `origin` | `github.com/butbeautifulv/cxado` | GitHub submodule URLs | Public dev, laptop |
| `gitlab` | `gitlab.svo.aero/av.popov/cxado` | **GitLab-only** URLs | P30 runner, corp CI, airgap |

GitHub and GitLab **diverge by design** on `.gitmodules` only. Same code + submodule SHAs; corp tree never references GitHub.

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
| `.gitmodules.gitlab` | GitLab URLs — template for corp overlay commit |
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
| **As needed** | `projects/veneno`, MCP repos |
| **Low priority** | `shared/skills`, `shared/references`, `shared/agent-rules`, `shared/gui` |
| **Optional** | `projects/fabrica`, `projects/tabula`, … |

## GitLab pull mirror (alternative)

Admin can configure **Pull mirror** on each GitLab project — only if GitLab server can reach GitHub (often blocked in corp). Manual `sync-monorepo-to-gitlab.sh` from laptop is the default.
