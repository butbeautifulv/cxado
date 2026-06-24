package cache

import (
	"sync"
	"time"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
)

type entry struct {
	token domain.Token
}

// Memory is an in-memory token cache with expiry skew.
type Memory struct {
	skew time.Duration
	mu   sync.RWMutex
	data map[string]entry
}

func NewMemory(skewSec int) *Memory {
	if skewSec < 0 {
		skewSec = 0
	}
	return &Memory{
		skew: time.Duration(skewSec) * time.Second,
		data: map[string]entry{},
	}
}

func (m *Memory) Get(key string, now time.Time) (domain.Token, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	e, ok := m.data[key]
	if !ok {
		return domain.Token{}, false
	}
	if !now.Before(e.token.ExpiresAt.Add(-m.skew)) {
		return domain.Token{}, false
	}
	return e.token, true
}

func (m *Memory) Put(key string, token domain.Token) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.data[key] = entry{token: token}
}
