package client

import (
	"sync"
	"time"
)

type cacheEntry struct {
	token     string
	expiresAt time.Time
}

type localCache struct {
	mu    sync.Mutex
	items map[string]cacheEntry
	skew  time.Duration
}

func newLocalCache() *localCache {
	return &localCache{
		items: map[string]cacheEntry{},
		skew:  30 * time.Second,
	}
}

func cacheKey(audience string, scopes []string) string {
	if len(scopes) == 0 {
		return audience
	}
	out := audience
	for _, s := range scopes {
		out += "\x00" + s
	}
	return out
}

func (c *localCache) get(key string) (string, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	e, ok := c.items[key]
	if !ok {
		return "", false
	}
	if !time.Now().Before(e.expiresAt.Add(-c.skew)) {
		delete(c.items, key)
		return "", false
	}
	return e.token, true
}

func (c *localCache) put(key, token string, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.items[key] = cacheEntry{token: token, expiresAt: time.Now().Add(ttl)}
}
