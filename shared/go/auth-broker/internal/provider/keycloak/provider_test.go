package keycloak

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
)

func TestClientCredentials(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method", http.StatusMethodNotAllowed)
			return
		}
		_ = r.ParseForm()
		if r.Form.Get("grant_type") != "client_credentials" {
			http.Error(w, "grant", http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"access_token": "tok",
			"token_type":   "Bearer",
			"expires_in":   300,
		})
	}))
	defer srv.Close()

	p := New(srv.Client())
	tok, err := p.ClientCredentials(context.Background(), domain.ClientCredentialsRequest{
		ClientID:     "id",
		ClientSecret: "sec",
		TokenURL:     srv.URL,
		Scopes:       []string{"openid"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if tok.AccessToken != "tok" {
		t.Fatalf("token = %q", tok.AccessToken)
	}
}

func TestClientCredentialsErrors(t *testing.T) {
	p := New(http.DefaultClient)

	unauth := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "nope", http.StatusUnauthorized)
	}))
	defer unauth.Close()

	_, err := p.ClientCredentials(context.Background(), domain.ClientCredentialsRequest{
		ClientID: "id", ClientSecret: "sec", TokenURL: unauth.URL,
	})
	if err == nil {
		t.Fatal("expected error")
	}

	serverErr := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "boom", http.StatusInternalServerError)
	}))
	defer serverErr.Close()

	_, err = p.ClientCredentials(context.Background(), domain.ClientCredentialsRequest{
		ClientID: "id", ClientSecret: "sec", TokenURL: serverErr.URL,
	})
	if err == nil {
		t.Fatal("expected provider error")
	}
}
