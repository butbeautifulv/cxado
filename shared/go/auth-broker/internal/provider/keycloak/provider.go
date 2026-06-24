package keycloak

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
)

// Provider implements client_credentials against a Keycloak (or OIDC) token endpoint.
type Provider struct {
	httpClient *http.Client
}

func New(httpClient *http.Client) *Provider {
	if httpClient == nil {
		httpClient = http.DefaultClient
	}
	return &Provider{httpClient: httpClient}
}

func (p *Provider) ClientCredentials(ctx context.Context, req domain.ClientCredentialsRequest) (domain.Token, error) {
	form := url.Values{}
	form.Set("grant_type", "client_credentials")
	form.Set("client_id", req.ClientID)
	form.Set("client_secret", req.ClientSecret)
	if len(req.Scopes) > 0 {
		form.Set("scope", strings.Join(req.Scopes, " "))
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, req.TokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return domain.Token{}, fmt.Errorf("%w: %v", domain.ErrProvider, err)
	}
	httpReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := p.httpClient.Do(httpReq)
	if err != nil {
		return domain.Token{}, fmt.Errorf("%w: %v", domain.ErrProvider, err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		return domain.Token{}, fmt.Errorf("%w: status %d", domain.ErrProvider, resp.StatusCode)
	}

	var out struct {
		AccessToken string `json:"access_token"`
		TokenType   string `json:"token_type"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &out); err != nil {
		return domain.Token{}, fmt.Errorf("%w: decode: %v", domain.ErrProvider, err)
	}
	if out.AccessToken == "" {
		return domain.Token{}, fmt.Errorf("%w: empty access_token", domain.ErrProvider)
	}
	tokenType := out.TokenType
	if tokenType == "" {
		tokenType = "Bearer"
	}
	expiresIn := out.ExpiresIn
	if expiresIn < 1 {
		expiresIn = 60
	}
	return domain.Token{
		AccessToken: out.AccessToken,
		TokenType:   tokenType,
		ExpiresAt:   time.Now().Add(time.Duration(expiresIn) * time.Second),
	}, nil
}
