package provider

import (
	"fmt"
	"net/http"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/config"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/provider/keycloak"
)

// Factory builds TokenProvider instances by provider name.
type Factory struct {
	keycloak *keycloak.Provider
}

func NewFactory(httpClient *http.Client) *Factory {
	return &Factory{keycloak: keycloak.New(httpClient)}
}

func (f *Factory) NewProvider(name string, _ config.AudienceConfig) (domain.TokenProvider, error) {
	switch name {
	case "keycloak":
		return f.keycloak, nil
	default:
		return nil, fmt.Errorf("unknown provider %q", name)
	}
}
