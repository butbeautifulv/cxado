package cache

import (
	"time"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
)

// Cache stores OAuth2 access tokens keyed by audience and scopes.
type Cache interface {
	Get(key string, now time.Time) (domain.Token, bool)
	Put(key string, token domain.Token)
}

// Key builds a stable cache key from audience and scopes.
func Key(audience string, scopes []string) string {
	if len(scopes) == 0 {
		return audience
	}
	out := audience
	for _, s := range scopes {
		out += "\x00" + s
	}
	return out
}
