# Veil MCP contract matrix (veil SOT ↔ egregore)

**SOT:** `projects/veil/knowledge/serve/internal/transport/mcpserver/tools.go`  
**Egregore client:** `projects/egregore/cys_core/integrations/veil_mcp_client.py`  
**Normalization:** `projects/egregore/cys_core/application/runs/tool_coercion.py`

## Phase 2 MVP tools

| Tool | Veil required args | Egregore normalization | Pre-MCP validation |
|------|-------------------|------------------------|-------------------|
| `ti_list_categories` | — | — | — |
| `ti_search_in_category` | `category`, `query` | `q`→`query`, `cat`→`category`, `ioc`→`ti`, default `ti` when query only | Reject empty query; reject unknown category |
| `playbook_search` | `query` optional | nested `kwargs` unwrap | — |
| `playbook_get` | `id` | `skill_id`, `playbook_id` aliases | Slug pattern `[a-z0-9-]+` |
| `playbook_procedure` | `id` | same as get | same as get |
| `playbook_for_technique` | `technique_id` | `technique`, `mitre_id` aliases; `1059.001`→`T1059.001` | ATT&CK format `T####(.###)?` |

## Category enum (graph pack)

`ti`, `vuln`, `mitre`, `detection`, `playbook`, `engage`, `sbom`, `code_rules`, `dast`, `lola`

LLM mistakes mapped:

| LLM value | Normalized |
|-----------|------------|
| `ioc`, `iocs`, `indicator` | `ti` |
| `cve`, `vulnerability` | `vuln` |
| `att&ck`, `mitre_attack` | `mitre` |

## Automated test

`projects/egregore/tests/integrations/test_veil_mcp_contract.py`

- Fixture mode (CI): category set parity, required-args table
- Live mode (`VEIL_MCP_URL` set): `ti_list_categories` + `ti_search_in_category` smoke
