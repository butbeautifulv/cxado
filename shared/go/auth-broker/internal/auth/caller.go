package auth

import (
	"net/http"
	"strings"
)

type contextKey string

const callerContextKey contextKey = "brokerCallerID"

// CallerFromContext returns the authenticated service caller ID.
func CallerFromContext(r *http.Request) string {
	if v := r.Context().Value(callerContextKey); v != nil {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

// WithCaller attaches caller ID to the request context.
func WithCaller(r *http.Request, callerID string) *http.Request {
	return r.WithContext(contextWithCaller(r.Context(), callerID))
}

// ExtractCaller derives caller ID from X-Service-Id or a default when using service token only.
func ExtractCaller(r *http.Request) string {
	if id := strings.TrimSpace(r.Header.Get("X-Service-Id")); id != "" {
		return id
	}
	return "default"
}

// BearerToken extracts the bearer token from Authorization header.
func BearerToken(h string) string {
	h = strings.TrimSpace(h)
	const prefix = "Bearer "
	if strings.HasPrefix(h, prefix) {
		return strings.TrimSpace(strings.TrimPrefix(h, prefix))
	}
	return ""
}
