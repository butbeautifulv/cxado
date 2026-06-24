package config

import (
	"os"
	"strconv"
	"strings"
)

func LoadFromEnv() Config {
	skew := 30
	if v := strings.TrimSpace(os.Getenv("BROKER_CACHE_SKEW_SEC")); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			skew = n
		}
	}
	return Config{
		HTTPAddr:      envOr("BROKER_HTTP_ADDR", ":8080"),
		GRPCAddr:      envOr("BROKER_GRPC_ADDR", ":9090"),
		ServiceToken:  strings.TrimSpace(os.Getenv("BROKER_SERVICE_TOKEN")),
		AudiencesFile: strings.TrimSpace(os.Getenv("BROKER_AUDIENCES_FILE")),
		CacheSkewSec:  skew,
		Prod:          envBool("BROKER_PROD", false),
	}
}

func envOr(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

func envBool(key string, def bool) bool {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return def
	}
	switch strings.ToLower(v) {
	case "1", "true", "yes", "on":
		return true
	default:
		return false
	}
}
