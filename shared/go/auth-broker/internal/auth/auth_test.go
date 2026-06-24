package auth

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestVerifyServiceToken(t *testing.T) {
	called := false
	h := VerifyServiceToken("secret", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		if CallerFromContext(r) != "svc-a" {
			t.Fatalf("caller = %q", CallerFromContext(r))
		}
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer secret")
	req.Header.Set("X-Service-Id", "svc-a")
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK || !called {
		t.Fatalf("status=%d called=%v", rr.Code, called)
	}

	req2 := httptest.NewRequest(http.MethodGet, "/", nil)
	req2.Header.Set("Authorization", "Bearer wrong")
	rr2 := httptest.NewRecorder()
	h.ServeHTTP(rr2, req2)
	if rr2.Code != http.StatusUnauthorized {
		t.Fatalf("status=%d", rr2.Code)
	}
}

func TestBearerToken(t *testing.T) {
	if BearerToken("Bearer abc") != "abc" {
		t.Fatal("bearer parse failed")
	}
	if BearerToken("Basic x") != "" {
		t.Fatal("expected empty")
	}
}
