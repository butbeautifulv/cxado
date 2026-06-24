package domain

import (
	"errors"
	"testing"
)

func TestErrorsIs(t *testing.T) {
	tests := []struct {
		err  error
		target error
	}{
		{ErrUnknownAudience, ErrUnknownAudience},
		{ErrUnauthorized, ErrUnauthorized},
		{ErrForbidden, ErrForbidden},
		{ErrProvider, ErrProvider},
	}
	for _, tc := range tests {
		if !errors.Is(tc.err, tc.target) {
			t.Fatalf("errors.Is(%v, %v) = false", tc.err, tc.target)
		}
	}
}
