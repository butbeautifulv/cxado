package httptransport

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/auth"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/cache"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/config"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/registry"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/service"
)

type stubProvider struct{}

func (stubProvider) ClientCredentials(_ context.Context, _ domain.ClientCredentialsRequest) (domain.Token, error) {
	return domain.Token{
		AccessToken: "access",
		TokenType:   "Bearer",
		ExpiresAt:   time.Now().Add(time.Minute),
	}, nil
}

type stubFactory struct{}

func (stubFactory) NewProvider(string, config.AudienceConfig) (domain.TokenProvider, error) {
	return stubProvider{}, nil
}

func TestTokenHandlerRoundTrip(t *testing.T) {
	reg := registry.New(map[string]config.AudienceConfig{
		"veil-api": {
			Provider: "keycloak", ClientID: "id", ClientSecret: "s", TokenURL: "http://x",
		},
	})
	svc := service.New(reg, registry.NewCallers(nil), cache.NewMemory(30), stubFactory{})
	h := auth.VerifyServiceToken("tok", &TokenHandler{Svc: svc})

	body, _ := json.Marshal(TokenRequest{Audience: "veil-api"})
	req := httptest.NewRequest(http.MethodPost, "/v1/token", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer tok")
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status=%d body=%s", rr.Code, rr.Body.String())
	}
	var resp TokenResponse
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.AccessToken != "access" {
		t.Fatalf("token=%q", resp.AccessToken)
	}
}
