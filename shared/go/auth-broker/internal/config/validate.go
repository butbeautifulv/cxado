package config

import "fmt"

// Validate checks broker configuration.
func (c Config) Validate() error {
	if c.ServiceToken == "" {
		return fmt.Errorf("BROKER_SERVICE_TOKEN is required")
	}
	if len(c.Audiences) == 0 {
		return fmt.Errorf("at least one audience is required")
	}
	for name, aud := range c.Audiences {
		if aud.Provider == "" {
			return fmt.Errorf("audience %q: provider is required", name)
		}
		if aud.Provider != "keycloak" {
			return fmt.Errorf("audience %q: unknown provider %q", name, aud.Provider)
		}
		if aud.ClientID == "" {
			return fmt.Errorf("audience %q: client_id is required", name)
		}
		if aud.ClientSecret == "" {
			return fmt.Errorf("audience %q: client_secret is required", name)
		}
		if aud.TokenURL == "" {
			return fmt.Errorf("audience %q: token_url is required", name)
		}
	}
	return nil
}
