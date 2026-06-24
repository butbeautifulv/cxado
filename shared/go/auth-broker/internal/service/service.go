package service

import (
	"context"
	"fmt"
	"time"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/cache"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/config"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/registry"
)

// Service orchestrates registry, cache, and OAuth2 providers.
type Service struct {
	registry *registry.Registry
	callers  *registry.Callers
	cache    cache.Cache
	factory  ProviderFactory
	now      func() time.Time
}

// ProviderFactory builds OAuth2 token providers.
type ProviderFactory interface {
	NewProvider(name string, cfg config.AudienceConfig) (domain.TokenProvider, error)
}

func New(reg *registry.Registry, callers *registry.Callers, c cache.Cache, factory ProviderFactory) *Service {
	return &Service{
		registry: reg,
		callers:  callers,
		cache:    c,
		factory:  factory,
		now:      time.Now,
	}
}

// GetAccessToken returns a cached or freshly fetched access token.
func (s *Service) GetAccessToken(ctx context.Context, callerID, audience string, scopes []string) (domain.Token, error) {
	if !s.callers.CanRequest(callerID, audience) {
		return domain.Token{}, domain.ErrForbidden
	}
	audCfg, err := s.registry.Lookup(audience)
	if err != nil {
		return domain.Token{}, err
	}
	key := cache.Key(audience, scopes)
	now := s.now()
	if tok, ok := s.cache.Get(key, now); ok {
		return tok, nil
	}
	prov, err := s.factory.NewProvider(audCfg.Provider, audCfg)
	if err != nil {
		return domain.Token{}, fmt.Errorf("%w: %v", domain.ErrProvider, err)
	}
	reqScopes := scopes
	if len(reqScopes) == 0 && len(audCfg.Scopes) > 0 {
		reqScopes = audCfg.Scopes
	}
	tok, err := prov.ClientCredentials(ctx, domain.ClientCredentialsRequest{
		ClientID:     audCfg.ClientID,
		ClientSecret: audCfg.ClientSecret,
		TokenURL:     audCfg.TokenURL,
		Scopes:       reqScopes,
	})
	if err != nil {
		return domain.Token{}, err
	}
	s.cache.Put(key, tok)
	return tok, nil
}
