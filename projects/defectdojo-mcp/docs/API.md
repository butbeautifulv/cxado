# DefectDojo API v2 — MCP reference

Curated subset for `defectdojo-mcp`. Full OpenAPI: `shared/references/DefectDojo API v2.json`.

## Authentication

```bash
curl -H "Authorization: Token $DEFECTDOJO_API_KEY" \
  "$DEFECTDOJO_BASE_URL/api/v2/findings/?limit=5"
```

## Pagination

List endpoints return `{ count, next, previous, results }`. Use `limit` and `offset` query params.

## Findings

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v2/findings/` | List findings |
| GET | `/api/v2/findings/{id}/` | Get finding |
| PATCH | `/api/v2/findings/{id}/` | Update finding |
| POST | `/api/v2/findings/{id}/close/` | Close finding |
| POST | `/api/v2/findings/{id}/verify/` | Verify finding |
| GET | `/api/v2/findings/{id}/notes/` | List notes |
| POST | `/api/v2/findings/{id}/notes/` | Add note |
| POST | `/api/v2/findings/accept_risks/` | Bulk risk acceptance |

### Finding query parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| severity | string | Critical, High, Medium, Low, Info |
| active | boolean | Active findings only |
| verified | boolean | Verified findings only |
| duplicate | boolean | Include duplicates |
| product | integer | Product ID |
| test | integer | Test ID |
| limit | integer | Page size |
| offset | integer | Pagination offset |

## Products / Engagements / Tests

| Method | Endpoint |
|--------|----------|
| GET/POST | `/api/v2/products/` |
| GET | `/api/v2/products/{id}/` |
| GET/POST | `/api/v2/engagements/` |
| GET | `/api/v2/engagements/{id}/` |
| POST | `/api/v2/engagements/{id}/close/` |
| GET/POST | `/api/v2/tests/` |
| GET | `/api/v2/tests/{id}/` |

## Import scan (CI/CD)

| Method | Endpoint | Content-Type |
|--------|----------|--------------|
| POST | `/api/v2/import-scan/` | multipart/form-data |
| POST | `/api/v2/reimport-scan/` | multipart/form-data |
| POST | `/api/v2/import-scan/preview/` | multipart/form-data |

### import-scan form fields

| Field | Required | Description |
|-------|----------|-------------|
| file | yes | Scanner report file |
| scan_type | yes | Scanner type (see below) |
| product | no* | Product ID |
| engagement | no* | Engagement ID |
| test | no | Existing test for reimport |
| active | no | Default true |
| verified | no | Default false |
| minimum_severity | no | Info, Low, Medium, High, Critical |
| auto_create_context | no | Auto-create product/engagement |
| product_name | no | With auto_create_context |
| engagement_name | no | With auto_create_context |
| test_title | no | Test title |
| build_id | no | CI build ID |
| branch_tag | no | Git branch/tag |
| commit_hash | no | Git commit |

\* Either provide product/engagement IDs or use `auto_create_context=true` with names.

### Common scan_type values (CI/CD)

| Scanner | scan_type |
|---------|-----------|
| Semgrep | Semgrep JSON Report |
| Trivy | Trivy Scan |
| SARIF | SARIF |
| Checkov | Checkov Scan |
| Nuclei | Nuclei Scan |
| OWASP ZAP | ZAP Scan |
| Snyk | Snyk Scan |
| Nessus | Nessus Scan |

## Example: import Semgrep report

```bash
curl -X POST "$DEFECTDOJO_BASE_URL/api/v2/import-scan/" \
  -H "Authorization: Token $DEFECTDOJO_API_KEY" \
  -F "scan_type=Semgrep JSON Report" \
  -F "product=1" \
  -F "engagement=2" \
  -F "active=true" \
  -F "verified=false" \
  -F "file=@semgrep.json"
```

## Example: triage workflow

1. `GET /api/v2/findings/?severity=High&active=true`
2. `GET /api/v2/findings/{id}/`
3. `GET /api/v2/findings/{id}/notes/`
4. `PATCH /api/v2/findings/{id}/` — update severity/status
5. `POST /api/v2/findings/{id}/notes/` — triage comment
6. `POST /api/v2/findings/{id}/verify/` or `accept_risks`

## Health check

`GET /api/v2/users/?limit=1` — lightweight auth probe used by MCP readiness.
