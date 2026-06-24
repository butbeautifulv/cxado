package client

// TokenResponse mirrors the HTTP /v1/token JSON response.
type TokenResponse struct {
	AccessToken string `json:"access_token"`
	ExpiresIn   int32  `json:"expires_in"`
	TokenType   string `json:"token_type"`
}

// TokenRequest mirrors the HTTP /v1/token JSON request.
type TokenRequest struct {
	Audience string   `json:"audience"`
	Scopes   []string `json:"scopes,omitempty"`
}
