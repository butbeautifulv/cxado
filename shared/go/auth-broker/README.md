# cxado auth-broker

Centralized OAuth2 M2M token broker (client credentials). See [ADR](../../../docs/adr/auth-token-broker.md).

## Quick start

```bash
export BROKER_SERVICE_TOKEN=dev-secret
export BROKER_AUDIENCES_FILE=./config.example.yaml
# Edit config.example.yaml: set real client_secret via env expansion in your deploy layer.

make run
```

## HTTP

```bash
curl -sS -X POST http://localhost:8080/v1/token \
  -H "Authorization: Bearer dev-secret" \
  -H "X-Service-Id: veneno-engage" \
  -H "Content-Type: application/json" \
  -d '{"audience":"veil-api","scopes":["openid"]}'
```

## Environment

| Variable | Default | Description |
|----------|---------|-------------|
| `BROKER_HTTP_ADDR` | `:8080` | HTTP listen address |
| `BROKER_GRPC_ADDR` | `:9090` | gRPC listen address |
| `BROKER_SERVICE_TOKEN` | — | Required static token for clients |
| `BROKER_AUDIENCES_FILE` | — | YAML audiences + caller allowlist |
| `BROKER_CACHE_SKEW_SEC` | `30` | Refresh tokens this many seconds before expiry |
| `BROKER_PROD` | `false` | Reserved for stricter error responses |

## Development

```bash
make test
make proto-gen   # requires protoc + protoc-gen-go + protoc-gen-go-grpc
make build
```

## Go client

See [client/README.md](client/README.md).
