package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/auth"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/cache"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/config"
	brokerlog "github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/log"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/provider"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/registry"
	"github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/service"
	grpctransport "github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/transport/grpc"
	httptransport "github.com/butbeautifulv/cxado/shared/go/auth-broker/internal/transport/http"
)

func main() {
	cfg := config.LoadFromEnv()
	if cfg.AudiencesFile != "" {
		audiences, callers, err := config.ParseAudiencesYAML(cfg.AudiencesFile)
		if err != nil {
			slog.Error("load audiences", "err", err)
			os.Exit(1)
		}
		cfg.Audiences = audiences
		cfg.Callers = callers
	}
	if err := cfg.Validate(); err != nil {
		slog.Error("invalid config", "err", err)
		os.Exit(1)
	}

	base := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})
	slog.SetDefault(slog.New(brokerlog.NewRedactHandler(base)))

	reg := registry.New(cfg.Audiences)
	callers := registry.NewCallers(cfg.Callers)
	memCache := cache.NewMemory(cfg.CacheSkewSec)
	factory := provider.NewFactory(http.DefaultClient)
	svc := service.New(reg, callers, memCache, factory)

	grpcSrv, err := grpctransport.NewServer(cfg.GRPCAddr, cfg.ServiceToken, svc)
	if err != nil {
		slog.Error("grpc listen", "err", err)
		os.Exit(1)
	}

	mux := http.NewServeMux()
	mux.Handle("/health", httptransport.HealthHandler())
	mux.Handle("/v1/token", auth.VerifyServiceToken(cfg.ServiceToken, &httptransport.TokenHandler{Svc: svc}))
	httpSrv := &http.Server{Addr: cfg.HTTPAddr, Handler: mux}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	errCh := make(chan error, 2)
	go func() { errCh <- grpcSrv.Serve() }()
	go func() { errCh <- httpSrv.ListenAndServe() }()

	slog.Info("auth-broker started", "http", cfg.HTTPAddr, "grpc", cfg.GRPCAddr)

	select {
	case <-ctx.Done():
		slog.Info("shutting down")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		grpcSrv.GracefulStop()
		_ = httpSrv.Shutdown(shutdownCtx)
	case err := <-errCh:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("server error", "err", err)
			os.Exit(1)
		}
	}
}
