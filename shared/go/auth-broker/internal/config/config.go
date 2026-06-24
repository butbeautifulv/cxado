package config

// Config holds broker runtime settings.
type Config struct {
	HTTPAddr       string
	GRPCAddr       string
	ServiceToken   string
	AudiencesFile  string
	Audiences      map[string]AudienceConfig
	Callers        map[string]CallerConfig
	CacheSkewSec   int
	Prod           bool
}

// AudienceConfig maps a logical audience to an OAuth2 provider.
type AudienceConfig struct {
	Provider     string   `yaml:"provider"`
	ClientID     string   `yaml:"client_id"`
	ClientSecret string   `yaml:"client_secret"`
	TokenURL     string   `yaml:"token_url"`
	Scopes       []string `yaml:"scopes"`
}

// CallerConfig defines which audiences a service caller may request.
type CallerConfig struct {
	Audiences []string `yaml:"audiences"`
}
