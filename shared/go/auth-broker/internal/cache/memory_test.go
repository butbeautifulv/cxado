package cache

import (
	"testing"
	"time"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
)

func TestMemoryCache(t *testing.T) {
	c := NewMemory(30)
	now := time.Now()
	key := Key("veil-api", []string{"openid"})
	tok := domain.Token{
		AccessToken: "abc",
		TokenType:   "Bearer",
		ExpiresAt:   now.Add(60 * time.Second),
	}
	c.Put(key, tok)

	got, ok := c.Get(key, now)
	if !ok || got.AccessToken != "abc" {
		t.Fatalf("cache miss or wrong token: %#v %v", got, ok)
	}

	// After expiry minus skew, treat as miss.
	late := now.Add(31 * time.Second)
	if _, ok := c.Get(key, late); ok {
		t.Fatal("expected expired cache entry")
	}
}

func TestCacheKey(t *testing.T) {
	if Key("a", nil) != "a" {
		t.Fatal("empty scopes key")
	}
	if Key("a", []string{"s1", "s2"}) == Key("a", []string{"s1"}) {
		t.Fatal("scopes should affect key")
	}
}
