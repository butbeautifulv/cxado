package log

import (
	"context"
	"log/slog"
	"strings"
)

const redacted = "[REDACTED]"

var sensitiveKeys = []string{"access_token", "accessToken", "token", "client_secret", "clientSecret"}

// RedactHandler wraps a slog handler and redacts sensitive attribute keys.
type RedactHandler struct {
	inner slog.Handler
}

func NewRedactHandler(inner slog.Handler) *RedactHandler {
	return &RedactHandler{inner: inner}
}

func (h *RedactHandler) Enabled(ctx context.Context, level slog.Level) bool {
	return h.inner.Enabled(ctx, level)
}

func (h *RedactHandler) Handle(ctx context.Context, r slog.Record) error {
	r = r.Clone()
	attrs := make([]slog.Attr, 0, r.NumAttrs())
	r.Attrs(func(a slog.Attr) bool {
		attrs = append(attrs, redactAttr(a))
		return true
	})
	r2 := slog.NewRecord(r.Time, r.Level, r.Message, r.PC)
	r2.AddAttrs(attrs...)
	return h.inner.Handle(ctx, r2)
}

func (h *RedactHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	out := make([]slog.Attr, len(attrs))
	for i, a := range attrs {
		out[i] = redactAttr(a)
	}
	return &RedactHandler{inner: h.inner.WithAttrs(out)}
}

func (h *RedactHandler) WithGroup(name string) slog.Handler {
	return &RedactHandler{inner: h.inner.WithGroup(name)}
}

func redactAttr(a slog.Attr) slog.Attr {
	key := strings.ToLower(a.Key)
	for _, sk := range sensitiveKeys {
		if key == sk {
			return slog.String(a.Key, redacted)
		}
	}
	return a
}
