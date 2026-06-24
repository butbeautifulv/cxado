package client

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Config configures the auth-broker HTTP client.
type Config struct {
	BaseURL      string
	ServiceToken string
	ServiceID    string
	HTTPClient   *http.Client
}

// Client fetches OAuth2 access tokens from the auth-broker.
type Client struct {
	cfg   Config
	cache *localCache
}

func New(cfg Config) *Client {
	if cfg.HTTPClient == nil {
		cfg.HTTPClient = http.DefaultClient
	}
	cfg.BaseURL = strings.TrimSuffix(strings.TrimSpace(cfg.BaseURL), "/")
	return &Client{cfg: cfg, cache: newLocalCache()}
}

// GetAccessToken returns a bearer access token for the given audience.
func (c *Client) GetAccessToken(ctx context.Context, audience string, scopes []string) (string, error) {
	if c.cfg.BaseURL == "" {
		return "", fmt.Errorf("auth broker base URL not configured")
	}
	key := cacheKey(audience, scopes)
	if tok, ok := c.cache.get(key); ok {
		return tok, nil
	}
	body, _ := json.Marshal(TokenRequest{Audience: audience, Scopes: scopes})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.cfg.BaseURL+"/v1/token", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.cfg.ServiceToken)
	if c.cfg.ServiceID != "" {
		req.Header.Set("X-Service-Id", c.cfg.ServiceID)
	}
	resp, err := c.cfg.HTTPClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("auth broker: %d %s", resp.StatusCode, string(raw))
	}
	var out TokenResponse
	if err := json.Unmarshal(raw, &out); err != nil {
		return "", err
	}
	if out.AccessToken == "" {
		return "", fmt.Errorf("auth broker: empty access_token")
	}
	ttl := time.Duration(out.ExpiresIn) * time.Second
	if ttl < time.Second {
		ttl = time.Second
	}
	c.cache.put(key, out.AccessToken, ttl)
	return out.AccessToken, nil
}
