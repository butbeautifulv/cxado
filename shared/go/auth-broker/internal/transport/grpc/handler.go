package grpctransport

import (
	"context"
	"errors"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/auth"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
	pb "github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/transport/grpc/pb/auth_broker/v1"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/service"
)

// TokenServer implements pb.TokenServiceServer.
type TokenServer struct {
	pb.UnimplementedTokenServiceServer
	Svc *service.Service
}

func (s *TokenServer) GetAccessToken(ctx context.Context, req *pb.GetAccessTokenRequest) (*pb.GetAccessTokenResponse, error) {
	if req == nil || req.GetAudience() == "" {
		return nil, status.Error(codes.InvalidArgument, "audience is required")
	}
	callerID := auth.CallerFromGRPCContext(ctx)
	tok, err := s.Svc.GetAccessToken(ctx, callerID, req.GetAudience(), req.GetScopes())
	if err != nil {
		return nil, mapError(err)
	}
	now := time.Now()
	return &pb.GetAccessTokenResponse{
		AccessToken: tok.AccessToken,
		ExpiresIn:   tok.ExpiresIn(now),
		TokenType:   tok.TokenType,
	}, nil
}

func mapError(err error) error {
	switch {
	case errors.Is(err, domain.ErrUnauthorized):
		return status.Error(codes.Unauthenticated, err.Error())
	case errors.Is(err, domain.ErrForbidden):
		return status.Error(codes.PermissionDenied, err.Error())
	case errors.Is(err, domain.ErrUnknownAudience):
		return status.Error(codes.NotFound, err.Error())
	case errors.Is(err, domain.ErrProvider):
		return status.Error(codes.Unavailable, err.Error())
	default:
		return status.Error(codes.Internal, "internal error")
	}
}
