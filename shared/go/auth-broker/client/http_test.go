package client

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetAccessToken(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer svc-tok" {
			http.Error(w, "auth", http.StatusUnauthorized)
			return
		}
		_ = json.NewEncoder(w).Encode(TokenResponse{
			AccessToken: "abc",
			ExpiresIn:   300,
			TokenType:   "Bearer",
		})
	}))
	defer srv.Close()

	c := New(Config{BaseURL: srv.URL, ServiceToken: "svc-tok", ServiceID: "test"})
	tok, err := c.GetAccessToken(context.Background(), "veil-api", nil)
	if err != nil {
		t.Fatal(err)
	}
	if tok != "abc" {
		t.Fatalf("token=%q", tok)
	}
	tok2, err := c.GetAccessToken(context.Background(), "veil-api", nil)
	if err != nil || tok2 != "abc" {
		t.Fatalf("cache miss: %v %q", err, tok2)
	}
}
