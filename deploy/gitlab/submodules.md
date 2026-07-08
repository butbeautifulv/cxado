# Submodules: GitHub vs GitLab mirrors

## Problem

P30 (GitLab runner + k3s) **cannot reach GitHub**. `git submodule update` with URLs from `.gitmodules` fails in CI.

Laptops on the open internet can keep using GitHub URLs in `.gitmodules` unchanged.

## Recommended strategy (phased)

| Phase | Repos | Why |
|-------|-------|-----|
| **Now** | `projects/egregore` | Egregore image + Helm chart for deploy pipeline |
| **Next** | `projects/veil` | `--with-veil` offline deploy |
| **As needed** | `projects/veneno`, MCP repos | Separate CI jobs |
| **Low priority** | `shared/skills`, `shared/references`, `shared/agent-rules`, `shared/gui` | Agent/docs; not required for runtime images |
| **Optional** | `projects/fabrica`, `projects/tabula`, … | No k3s deploy dependency today |

**Direction:** mirror **inward** to `gitlab.svo.aero/av.popov/<repo>` (GitHub remains upstream for public/dev). Do **not** mirror outward to GitHub from corp.

## How CI resolves submodules

`.gitlab-ci.yml` sets `GIT_SUBMODULE_STRATEGY: none` and runs:

```bash
./scripts/gitlab/ci-submodule-init.sh
```

That rewrites submodule URLs at job time:

```
https://github.com/butbeautifulv/egregore.git
  → git@gitlab.svo.aero:av.popov/egregore.git
```

Only paths in `CI_SUBMODULES` are fetched (default: `projects/egregore`).

## Push / refresh a mirror

```bash
# one submodule (creates GitLab project if missing)
./scripts/gitlab/push-submodule-mirror.sh projects/egregore
./scripts/gitlab/push-submodule-mirror.sh projects/veil
```

After pushing, re-run pipeline on `main`.

## GitLab pull mirror (alternative)

For hands-off sync, an admin can configure **Pull mirror** on each GitLab project (Settings → Repository → Mirroring). Requires GitLab server reachability to GitHub — often blocked in corp; manual `push-submodule-mirror.sh` from laptop is simpler.

## Changing `.gitmodules` permanently?

Only if the team stops using GitHub entirely. Until then, keep GitHub URLs in `.gitmodules` and let CI rewrite for corp runners.
