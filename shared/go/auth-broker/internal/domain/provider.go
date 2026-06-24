package domain

import "context"

// ClientCredentialsRequest is sent to an OAuth2 token provider.
type ClientCredentialsRequest struct {
	ClientID     string
	ClientSecret string
	TokenURL     string
	Scopes       []string
}

// TokenProvider exchanges client credentials for access tokens.
type TokenProvider interface {
	ClientCredentials(ctx context.Context, req ClientCredentialsRequest) (Token, error)
}
