---
name: rag-security
description: Secure Retrieval-Augmented Generation pipelines — document poisoning, embedding manipulation, context window attacks, access control, vector index integrity, query abuse, output validation, and agent tool safety.
---

# RAG Security

## When to use

- RAG pipeline architecture review or threat modeling
- Document ingestion and vector store hardening
- Access control / tenant isolation in retrieval
- Agent + RAG integration (retrieved content → tool calls)
- RAG-specific incident response (poisoned corpus, cache leakage)

## Implementation priority

**Foundational:** document hashing at ingestion; context delimiters + chunk limits; per-chunk ACL metadata enforced at retrieval; tenant isolation; query normalization and rate limiting; output validation; fail-closed on integrity/policy failure.

## Pipeline controls by stage

### Document ingestion (poisoning)

- Hash + provenance; scan for injection markers and invisible Unicode.
- Allowlist trusted sources; approval workflow for new sources.

### Context window attacks

- Delimiters around retrieved content; reinforce system prompt after chunks.
- Scan chunks for instruction markers before inclusion.
- Retrieved content is **DATA**, not **COMMANDS**.

### Access control inheritance

- Store ACL metadata on every chunk; enforce at retrieval time.
- Pre-retrieval filtering; cascading deletion when source removed.

### Index integrity

- Checksum verification; write access only via ingestion pipeline.
- Log modifications; auth + network isolation on vector DB.

### Agent + RAG tool safety

- HITL for high-risk actions; tool authorization independent of model decision.
- Per-context tool allowlist; circuit breakers on anomalous tool volume.

### Caching

- Scope cache by user/tenant/permission; no shared cache across permission boundaries.

## CI/CD red-team minimum

| Test | Pass criteria |
|------|---------------|
| Poisoned doc retrieval | Known-bad doc not surfaced or blocked |
| Indirect prompt injection | Retrieved content does not override system prompt |
| Cross-tenant retrieval | Zero cross-boundary chunks |
| Unauthorized tool invocation | RAG output cannot trigger disallowed tools |

## Output guidance

- Identify which pipeline stage failed (ingestion, retrieval, context, output, tool).
- Recommend fail-closed behavior when integrity or policy lookup fails.

## References

- [OWASP RAG Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/RAG_Security_Cheat_Sheet.html)
