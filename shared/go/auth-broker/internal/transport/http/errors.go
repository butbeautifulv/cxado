package httptransport

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
)

func writeJSONError(w http.ResponseWriter, err error) {
	status, msg := mapError(err)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": msg})
}

func mapError(err error) (int, string) {
	switch {
	case errors.Is(err, domain.ErrUnauthorized):
		return http.StatusUnauthorized, err.Error()
	case errors.Is(err, domain.ErrForbidden):
		return http.StatusForbidden, err.Error()
	case errors.Is(err, domain.ErrUnknownAudience):
		return http.StatusNotFound, err.Error()
	case errors.Is(err, domain.ErrProvider):
		return http.StatusBadGateway, err.Error()
	default:
		return http.StatusInternalServerError, "internal error"
	}
}
