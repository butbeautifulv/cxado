package domain

import "time"

// Token is an OAuth2 access token returned by a provider.
type Token struct {
	AccessToken string
	TokenType   string
	ExpiresAt   time.Time
}

// ExpiresIn returns seconds until expiry (minimum 1).
func (t Token) ExpiresIn(now time.Time) int32 {
	if t.ExpiresAt.IsZero() {
		return 1
	}
	sec := int32(t.ExpiresAt.Sub(now).Seconds())
	if sec < 1 {
		return 1
	}
	return sec
}
