package auth

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
)

// VerifyServiceToken wraps handlers requiring a static broker service token.
func VerifyServiceToken(expected string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if expected == "" {
			writeAuthErr(w, http.StatusUnauthorized, domain.ErrUnauthorized)
			return
		}
		raw := BearerToken(r.Header.Get("Authorization"))
		if raw == "" || raw != expected {
			writeAuthErr(w, http.StatusUnauthorized, domain.ErrUnauthorized)
			return
		}
		callerID := ExtractCaller(r)
		r = WithCaller(r, callerID)
		next.ServeHTTP(w, r)
	})
}

func writeAuthErr(w http.ResponseWriter, status int, err error) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": err.Error()})
}

func contextWithCaller(ctx context.Context, callerID string) context.Context {
	return context.WithValue(ctx, callerContextKey, callerID)
}
