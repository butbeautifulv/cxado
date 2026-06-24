package auth

import (
	"context"
	"strings"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
)

type grpcCallerKey struct{}

// UnaryServiceTokenInterceptor validates broker service token on gRPC calls.
func UnaryServiceTokenInterceptor(expected string) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, _ *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		if expected == "" {
			return nil, status.Error(codes.Unauthenticated, domain.ErrUnauthorized.Error())
		}
		md, ok := metadata.FromIncomingContext(ctx)
		if !ok {
			return nil, status.Error(codes.Unauthenticated, domain.ErrUnauthorized.Error())
		}
		authz := md.Get("authorization")
		if len(authz) == 0 {
			return nil, status.Error(codes.Unauthenticated, domain.ErrUnauthorized.Error())
		}
		raw := BearerToken(authz[0])
		if raw == "" || raw != expected {
			return nil, status.Error(codes.Unauthenticated, domain.ErrUnauthorized.Error())
		}
		callerID := "default"
		if ids := md.Get("x-service-id"); len(ids) > 0 {
			callerID = strings.TrimSpace(ids[0])
		}
		ctx = context.WithValue(ctx, grpcCallerKey{}, callerID)
		return handler(ctx, req)
	}
}

// CallerFromGRPCContext returns caller ID set by the interceptor.
func CallerFromGRPCContext(ctx context.Context) string {
	if v := ctx.Value(grpcCallerKey{}); v != nil {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return "default"
}
