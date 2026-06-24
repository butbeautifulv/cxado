package config

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type audiencesFile struct {
	Audiences map[string]AudienceConfig `yaml:"audiences"`
	Callers   map[string]CallerConfig   `yaml:"callers"`
}

// ParseAudiencesYAML loads audiences and callers from a YAML file.
func ParseAudiencesYAML(path string) (map[string]AudienceConfig, map[string]CallerConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, nil, fmt.Errorf("read audiences file: %w", err)
	}
	var doc audiencesFile
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return nil, nil, fmt.Errorf("parse audiences yaml: %w", err)
	}
	if doc.Audiences == nil {
		doc.Audiences = map[string]AudienceConfig{}
	}
	if doc.Callers == nil {
		doc.Callers = map[string]CallerConfig{}
	}
	return doc.Audiences, doc.Callers, nil
}
