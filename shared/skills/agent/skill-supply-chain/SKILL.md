---
name: skill-supply-chain
description: Vet external agent skills and MCP servers for prompt injection, hidden instructions, and auto-exec risk. Use when onboarding third-party skills or assessing MCP tool security.
---

# Skill & MCP Supply Chain Security

## When to use

- Onboarding external/community skill packs
- Reviewing MCP server permissions and behavior
- Pre-release skill vetting in CI
- Investigating suspicious skill content or hidden instructions
- Supply chain audit of agent capabilities

## Vetting checklist (required before runtime)

1. SHA-256 hash recorded in registry manifest
2. Prompt injection scan on full skill body (not metadata alone)
3. Review `scripts/` for auto-exec, network calls, credential access
4. Human approval for community/untrusted tier
5. Pin `version` + `hash` in manifest — CI blocks drift

## Threat patterns in skills/MCP

| Risk | Indicator |
|------|-----------|
| Hidden instructions | Base64/Unicode-obfuscated commands in SKILL.md or scripts |
| Prompt injection | Role hijack, exfiltration via tool params |
| Over-permissioned MCP | Wildcard shell, unrestricted file/network access |
| Auto-exec scripts | `scripts/` that run shell/code without explicit user trigger |
| Dependency drift | Unpinned versions, floating tags |
| Data exfiltration | Skill instructs agent to send context to external URL |

## MCP tool hardening

**Bad:** unrestricted shell — `allowed_commands: "*"`.

**Good:** scoped access — path allowlists, read-only ops, blocked patterns (`*.env`, `*.key`, `*secret*`).

Apply same least-privilege as native tools; separate tool sets by trust level.

## Cisco AI Defense tooling (reference)

| Tool | Purpose |
|------|---------|
| [Skill Scanner](https://github.com/cisco-ai-defense/skill-scanner) | Malicious behaviors, hidden instructions in agent skills |
| [MCP Scanner](https://github.com/cisco-ai-defense/mcp-scanner) | MCP server behavioral threat analysis |
| [A2A Scanner](https://github.com/cisco-ai-defense/a2a-scanner) | Agent-to-agent communication threats |
| [DefenseClaw](https://github.com/cisco-ai-defense/defenseclaw) | Governance — scan/enforce/audit skills, MCP, plugins |

## Review workflow

1. Stage pack in quarantine — do not add to runtime manifest yet
2. Hash all bundled files; record in manifest draft
3. Run injection scan on full body
4. Review scripts for auto-exec risk
5. Compare requested tools vs persona allowlist — reject scope creep
6. Sign-off for community tier; pin version+hash; enable in allowlist

## Output guidance

- Report: hash, trust tier, injection scan result, script risk, approval status.
- Block runtime load until all checklist items pass.

## References

- [OWASP Software Supply Chain Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Software_Supply_Chain_Security_Cheat_Sheet.html)
