package registry

import (
	"testing"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/config"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
)

func TestRegistryLookup(t *testing.T) {
	reg := New(map[string]config.AudienceConfig{
		"veil-api": {Provider: "keycloak", ClientID: "id"},
	})
	cfg, err := reg.Lookup("veil-api")
	if err != nil {
		t.Fatal(err)
	}
	if cfg.ClientID != "id" {
		t.Fatalf("client_id = %q", cfg.ClientID)
	}
	_, err = reg.Lookup("missing")
	if err != domain.ErrUnknownAudience {
		t.Fatalf("err = %v", err)
	}
}

func TestCallersAllowlist(t *testing.T) {
	c := NewCallers(map[string]config.CallerConfig{
		"veneno": {Audiences: []string{"veil-api"}},
	})
	if !c.CanRequest("veneno", "veil-api") {
		t.Fatal("expected allow")
	}
	if c.CanRequest("veneno", "other") {
		t.Fatal("expected deny")
	}
	if c.CanRequest("unknown", "veil-api") {
		t.Fatal("expected deny unknown caller")
	}

	open := NewCallers(nil)
	if !open.CanRequest("any", "veil-api") {
		t.Fatal("expected open policy when no callers configured")
	}
}
