package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadFromEnv(t *testing.T) {
	t.Setenv("BROKER_HTTP_ADDR", ":18080")
	t.Setenv("BROKER_GRPC_ADDR", ":19090")
	t.Setenv("BROKER_CACHE_SKEW_SEC", "45")

	cfg := LoadFromEnv()
	if cfg.HTTPAddr != ":18080" {
		t.Fatalf("HTTPAddr = %q", cfg.HTTPAddr)
	}
	if cfg.GRPCAddr != ":19090" {
		t.Fatalf("GRPCAddr = %q", cfg.GRPCAddr)
	}
	if cfg.CacheSkewSec != 45 {
		t.Fatalf("CacheSkewSec = %d", cfg.CacheSkewSec)
	}
}

func TestParseAudiencesYAML(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "audiences.yaml")
	const body = `
audiences:
  veil-api:
    provider: keycloak
    client_id: veneno-engage
    client_secret: secret
    token_url: https://keycloak.example/realms/cxado/protocol/openid-connect/token
    scopes: [openid]
callers:
  veneno-engage:
    audiences: [veil-api]
`
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	audiences, callers, err := ParseAudiencesYAML(path)
	if err != nil {
		t.Fatal(err)
	}
	if audiences["veil-api"].ClientID != "veneno-engage" {
		t.Fatalf("audience client_id = %q", audiences["veil-api"].ClientID)
	}
	if len(callers["veneno-engage"].Audiences) != 1 {
		t.Fatalf("callers = %#v", callers)
	}
}

func TestValidate(t *testing.T) {
	cfg := Config{
		ServiceToken: "tok",
		Audiences: map[string]AudienceConfig{
			"veil-api": {
				Provider:     "keycloak",
				ClientID:     "id",
				ClientSecret: "sec",
				TokenURL:     "https://example/token",
			},
		},
	}
	if err := cfg.Validate(); err != nil {
		t.Fatal(err)
	}

	cfg.Audiences["veil-api"] = AudienceConfig{Provider: "keycloak"}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected validation error for empty token_url")
	}
}
