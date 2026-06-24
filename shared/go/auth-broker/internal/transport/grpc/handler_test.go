package grpctransport

import (
	"context"
	"net"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/test/bufconn"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/auth"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/cache"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/config"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/domain"
	pb "github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/transport/grpc/pb/auth_broker/v1"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/registry"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/service"
)

const bufSize = 1024 * 1024

type stubProvider struct{}

func (stubProvider) ClientCredentials(_ context.Context, _ domain.ClientCredentialsRequest) (domain.Token, error) {
	return domain.Token{
		AccessToken: "grpc-tok",
		TokenType:   "Bearer",
		ExpiresAt:   time.Now().Add(time.Minute),
	}, nil
}

type stubFactory struct{}

func (stubFactory) NewProvider(string, config.AudienceConfig) (domain.TokenProvider, error) {
	return stubProvider{}, nil
}

func TestGetAccessTokenGRPC(t *testing.T) {
	lis := bufconn.Listen(bufSize)
	reg := registry.New(map[string]config.AudienceConfig{
		"veil-api": {
			Provider: "keycloak", ClientID: "id", ClientSecret: "s", TokenURL: "http://x",
		},
	})
	svc := service.New(reg, registry.NewCallers(nil), cache.NewMemory(30), stubFactory{})
	s := grpc.NewServer(grpc.UnaryInterceptor(auth.UnaryServiceTokenInterceptor("secret")))
	pb.RegisterTokenServiceServer(s, &TokenServer{Svc: svc})
	go func() { _ = s.Serve(lis) }()
	t.Cleanup(s.Stop)

	ctx := context.Background()
	conn, err := grpc.DialContext(ctx, "bufnet",
		grpc.WithContextDialer(func(context.Context, string) (net.Conn, error) { return lis.Dial() }),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = conn.Close() })

	md := metadata.Pairs("authorization", "Bearer secret", "x-service-id", "test")
	ctx = metadata.NewOutgoingContext(ctx, md)
	client := pb.NewTokenServiceClient(conn)
	resp, err := client.GetAccessToken(ctx, &pb.GetAccessTokenRequest{Audience: "veil-api"})
	if err != nil {
		t.Fatal(err)
	}
	if resp.GetAccessToken() != "grpc-tok" {
		t.Fatalf("token=%q", resp.GetAccessToken())
	}
}
