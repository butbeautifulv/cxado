package httptransport

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/auth"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/service"
)

// TokenRequest is the HTTP POST /v1/token body.
type TokenRequest struct {
	Audience string   `json:"audience"`
	Scopes   []string `json:"scopes"`
}

// TokenResponse is the HTTP POST /v1/token response.
type TokenResponse struct {
	AccessToken string `json:"access_token"`
	ExpiresIn   int32  `json:"expires_in"`
	TokenType   string `json:"token_type"`
}

// TokenHandler serves POST /v1/token.
type TokenHandler struct {
	Svc *service.Service
}

func (h *TokenHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		writeJSONError(w, err)
		return
	}
	var req TokenRequest
	if err := json.Unmarshal(body, &req); err != nil {
		writeJSONError(w, domain.ErrUnauthorized)
		return
	}
	req.Audience = strings.TrimSpace(req.Audience)
	if req.Audience == "" {
		writeJSONError(w, domain.ErrUnauthorized)
		return
	}
	callerID := auth.CallerFromContext(r)
	tok, err := h.Svc.GetAccessToken(r.Context(), callerID, req.Audience, req.Scopes)
	if err != nil {
		writeJSONError(w, err)
		return
	}
	now := time.Now()
	resp := TokenResponse{
		AccessToken: tok.AccessToken,
		ExpiresIn:   tok.ExpiresIn(now),
		TokenType:   tok.TokenType,
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}
