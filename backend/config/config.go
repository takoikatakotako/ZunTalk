package config

import (
	"os"
)

type Config struct {
	Port           string
	OpenAIAPIKey   string
	Maintenance    bool
	MinimumVersion string
}

func Load() *Config {
	maintenance := getEnv("MAINTENANCE", "false") == "true"

	return &Config{
		Port:           getEnv("PORT", "8080"),
		OpenAIAPIKey:   getEnv("OPENAI_API_KEY", ""),
		Maintenance:    maintenance,
		MinimumVersion: getEnv("MINIMUM_VERSION", "1.0.0"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
