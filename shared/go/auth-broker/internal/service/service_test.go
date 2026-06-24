package service

import (
	"context"
	"sync/atomic"
	"testing"
	"time"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/cache"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/config"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/registry"
)

type fakeProvider struct {
	calls atomic.Int32
}

func (f *fakeProvider) ClientCredentials(_ context.Context, _ domain.ClientCredentialsRequest) (domain.Token, error) {
	f.calls.Add(1)
	return domain.Token{
		AccessToken: "tok",
		TokenType:   "Bearer",
		ExpiresAt:   time.Now().Add(5 * time.Minute),
	}, nil
}

type stubFactory struct {
	p domain.TokenProvider
}

func (f *stubFactory) NewProvider(string, config.AudienceConfig) (domain.TokenProvider, error) {
	return f.p, nil
}

func TestGetAccessTokenCacheHit(t *testing.T) {
	fp := &fakeProvider{}
	reg := registry.New(map[string]config.AudienceConfig{
		"veil-api": {
			Provider:     "keycloak",
			ClientID:     "id",
			ClientSecret: "sec",
			TokenURL:     "http://example/token",
		},
	})
	svc := New(reg, registry.NewCallers(nil), cache.NewMemory(30), &stubFactory{p: fp})

	_, err := svc.GetAccessToken(context.Background(), "caller", "veil-api", nil)
	if err != nil {
		t.Fatal(err)
	}
	_, err = svc.GetAccessToken(context.Background(), "caller", "veil-api", nil)
	if err != nil {
		t.Fatal(err)
	}
	if fp.calls.Load() != 1 {
		t.Fatalf("provider calls = %d, want 1", fp.calls.Load())
	}
}

func TestGetAccessTokenForbidden(t *testing.T) {
	fp := &fakeProvider{}
	reg := registry.New(map[string]config.AudienceConfig{
		"veil-api": {Provider: "keycloak", ClientID: "id", ClientSecret: "s", TokenURL: "http://x"},
	})
	callers := registry.NewCallers(map[string]config.CallerConfig{
		"veneno": {Audiences: []string{"other"}},
	})
	svc := New(reg, callers, cache.NewMemory(30), &stubFactory{p: fp})
	_, err := svc.GetAccessToken(context.Background(), "veneno", "veil-api", nil)
	if err != domain.ErrForbidden {
		t.Fatalf("err = %v", err)
	}
}
