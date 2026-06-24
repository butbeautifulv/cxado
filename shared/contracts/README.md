# cxado wire contracts

Canonical JSON schemas for cross-repo integrations in the cxado ecosystem.

| Schema | Publisher | Consumer |
|--------|-----------|----------|
| `engage-events-audit.json` | veneno | veil `pipeline/engage-events` |
| `engage-events-finding.json` | veneno | veil `pipeline/engage-events` |
| `ingest-engage-tool-run.json` | veil pipeline bridge | veil `knowledge/ingest` |
| `ingest-engage-finding.json` | veil pipeline bridge | veil `knowledge/ingest` |

Veil keeps mirrors under `projects/veil/docs/schemas/` for standalone clones. When changing wire format, update **here first**, then mirror to veil.

Validate: `make test-contracts` from cxado root.
