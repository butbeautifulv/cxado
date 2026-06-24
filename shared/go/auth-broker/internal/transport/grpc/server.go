package grpctransport

import (
	"net"

	"google.golang.org/grpc"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/auth"
	pb "github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/transport/grpc/pb/auth_broker/v1"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/service"
)

// Server wraps a gRPC server for the token broker.
type Server struct {
	grpc *grpc.Server
	lis  net.Listener
}

// NewServer listens on addr and registers TokenService.
func NewServer(addr, serviceToken string, svc *service.Service) (*Server, error) {
	lis, err := net.Listen("tcp", addr)
	if err != nil {
		return nil, err
	}
	s := grpc.NewServer(grpc.UnaryInterceptor(auth.UnaryServiceTokenInterceptor(serviceToken)))
	pb.RegisterTokenServiceServer(s, &TokenServer{Svc: svc})
	return &Server{grpc: s, lis: lis}, nil
}

func (s *Server) Serve() error {
	return s.grpc.Serve(s.lis)
}

func (s *Server) GracefulStop() {
	s.grpc.GracefulStop()
}
