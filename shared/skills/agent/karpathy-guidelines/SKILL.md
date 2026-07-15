---
name: karpathy-guidelines
description: Karpathy-inspired behavioral guidelines — think first, surgical diffs, verifiable DoD, critic gate. Use when planning, implementing, or reviewing agent-assisted development.
---

# Karpathy guidelines (generic)

Behavioral guidelines from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876), adapted for phased agent workflows.

**Tradeoff:** Caution over speed on non-trivial work.

## Four principles

| # | Principle | Practice |
|---|-----------|----------|
| 1 | **Think before coding** | Read master + phase plan; state assumptions; ask if scope unclear |
| 2 | **Simplicity first** | KISS; no speculative features beyond the phase |
| 3 | **Surgical changes** | Diff ⊆ phase plan; no drive-by refactors |
| 4 | **Goal-driven execution** | Phase DoD → named verify commands; loop until green |

## Planning rhythm

1. Master plan → phase plan → feature branch → implement → PR → critic → merge → update master plan.

## Before writing code

- Phase plan and branch name identified.
- Dependencies merged on `main`.
- Success checks listed with concrete commands.

## On errors

Apply 5 Whys and Gemba Kaizen: reproduce with exact failing command, smallest root-cause fix, re-run verify.

Project-specific architecture and test commands live in project overlay rules and `shared/agent-rules/core/` via cxado `.cursor/rules/`.
