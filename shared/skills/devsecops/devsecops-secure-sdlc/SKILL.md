---
name: devsecops-secure-sdlc
description: >-
  Secure SDLC 8-stage model (Plan→Monitor): practices, gaps, mapping to DAF and
  template P0–F3. Use for SDLC docs, control placement, or cross-framework traceability.
---

# Secure SDLC (8 stages)

Canonical reference: Plan → Code → Build → Test → Release → Deploy → Operate → Monitor.

## Docs

| Doc | Content |
|-----|---------|
| `docs/references/secure-sdlc-phases.md` | Full stage definitions |
| `docs/references/sdlc-mapping.md` | 8 stages ↔ DAF ↔ P0–F3 ↔ pipeline |
| `docs/01-sdlc-process.md` | Four SDLC models overview |
| `docs/03-security-controls.md` | Control matrix with Secure SDLC column |

## Stage → template

See [sdlc-mapping.md](../../docs/references/sdlc-mapping.md) for full crosswalk including coverage column.

## Out of base CI (document only)

- Misuse/Abuse cases — Plan / threat model
- Performance, Chaos — Test/Operate
- PKI, IDS — Deploy/Operate runbooks

Related skills: `devsecops-daf`, `devsecops-fintech-sdlc`, `devsecops-phase-impl`.
