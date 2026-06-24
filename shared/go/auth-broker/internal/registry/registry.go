package registry

import (
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/config"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
)

// Registry maps logical audience names to OAuth2 configuration.
type Registry struct {
	audiences map[string]config.AudienceConfig
}

func New(audiences map[string]config.AudienceConfig) *Registry {
	if audiences == nil {
		audiences = map[string]config.AudienceConfig{}
	}
	return &Registry{audiences: audiences}
}

func (r *Registry) Lookup(audience string) (config.AudienceConfig, error) {
	cfg, ok := r.audiences[audience]
	if !ok {
		return config.AudienceConfig{}, domain.ErrUnknownAudience
	}
	return cfg, nil
}
