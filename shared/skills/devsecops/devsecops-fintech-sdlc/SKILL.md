---
name: devsecops-fintech-sdlc
description: >-
  Fintech secure SDLC swimlane: DEV/QA/UAT/PROD zones, MR security gate
  components, ASTO, fuzzing, roles. Use when designing process, writing
  01-sdlc-process.md, or aligning pipeline with fintech PDF.
---

# Fintech SDLC swimlane

Source: `docs/references/extracts/fintech-pdf.txt`, supplement [supplements/Типовой_процесс_...md](../../docs/references/supplements/Типовой_процесс_безопасной_разработки_для_финтеха.md)

Canonical docs:
- [01-sdlc-process.md](../../docs/01-sdlc-process.md) — operational synthesis (zones, roles, trunk flow, artifacts)
- [fintech-swimlane.md](../../docs/references/fintech-swimlane.md) — PDF diagram notes (IDE SAST variants, QA tool matrix, scheme comments)

## Agent actions

1. Align MR gate with B1–B6 template jobs (SAST, linters, secrets, forbidden files, SCA post-SBOM).
2. Map zones to pipeline stages: DEV/QA → MR; UAT → D1–D2; PROD → E/F phases.
3. For GOST 5.1–5.25 enumeration use the fintech supplement, not swimlane alone.
4. Bugfix fast-path: reduced gate documented in `01-sdlc-process.md` §Bugfix.

Roles & extended tables: [reference.md](reference.md) (links only).
