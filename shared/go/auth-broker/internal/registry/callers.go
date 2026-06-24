package registry

import "github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/config"

// Callers enforces per-service audience allowlists.
type Callers struct {
	callers map[string]config.CallerConfig
}

func NewCallers(callers map[string]config.CallerConfig) *Callers {
	if callers == nil {
		callers = map[string]config.CallerConfig{}
	}
	return &Callers{callers: callers}
}

// CanRequest reports whether callerID may request tokens for audience.
// When no callers are configured, all authenticated callers are allowed.
func (c *Callers) CanRequest(callerID, audience string) bool {
	if len(c.callers) == 0 {
		return true
	}
	cfg, ok := c.callers[callerID]
	if !ok {
		return false
	}
	for _, a := range cfg.Audiences {
		if a == audience {
			return true
		}
	}
	return false
}
