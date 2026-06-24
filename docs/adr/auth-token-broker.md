# ADR: OAuth2 Token Broker

| Field | Value |
|-------|-------|
| Status | accepted |
| Date | 2026-06-24 |

See also: [ecosystem-map.md](../ecosystem-map.md), [auth-broker-token-v1.json](../../shared/contracts/auth-broker-token-v1.json), [token.proto](../../shared/contracts/proto/auth_broker/v1/token.proto).

---

## PURPOSE

Centralized **OAuth2 token broker** for cxado M2M (client credentials). Services request access tokens by logical `audience` name without holding `client_secret`. The broker caches tokens and talks to Keycloak (or another OIDC provider via a swappable backend).

**Non-goals (v1):**
- Not a replacement for veil/veneno JWT **resource-server** middleware (`pkg/auth`)
- No Authorization Code / PKCE (user-facing login)
- No consumer migration in v1 (standalone service + client SDKs only)

## STACK

- **Language:** Go 1.25
- **Location:** `shared/go/auth-broker/`
- **Wire:** gRPC `TokenService` + HTTP `POST /v1/token`
- **Contracts:** `shared/contracts/auth-broker-token-v1.json`, `shared/contracts/proto/auth_broker/v1/token.proto`
- **IdP:** Keycloak default; `TokenProvider` interface for swap
- **Clients:** Go (`client/`), Python (`shared/python/cxado_auth_client/`)

## THREATS

| Risk | Mitigation |
|------|------------|
| Broker holds OAuth2 secrets | Secrets only in env/K8s secrets; never in git |
| Token leakage in logs | `slog` redaction of `access_token` fields |
| Lateral movement | Per-caller audience allowlist; short-lived access tokens |
| Replay | TLS in transit; static service token for client→broker (v1) |
| Provider lock-in | `TokenProvider` interface + config-driven provider name |

## API

**gRPC:** `TokenService.GetAccessToken(GetAccessTokenRequest) → GetAccessTokenResponse` — see [token.proto](../../shared/contracts/proto/auth_broker/v1/token.proto).

**HTTP:** `POST /v1/token` with JSON body `{ "audience": "veil-api", "scopes": [] }` — see [auth-broker-token-v1.json](../../shared/contracts/auth-broker-token-v1.json).

**Client authentication (v1):** `Authorization: Bearer <BROKER_SERVICE_TOKEN>` plus caller ID (`X-Service-Id` or token-derived). Caller allowlist maps service ID → permitted audiences.

**Health:** `GET /health` → `{"ok":true}`.
