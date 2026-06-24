package domain

import "errors"

var (
	ErrUnknownAudience = errors.New("unknown audience")
	ErrUnauthorized    = errors.New("unauthorized")
	ErrForbidden       = errors.New("forbidden")
	ErrProvider        = errors.New("token provider error")
)
