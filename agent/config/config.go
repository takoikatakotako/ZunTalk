package config

import "os"

// Config はエージェントサーバーの設定。環境変数から読み込む。
type Config struct {
	// Port は HTTP サーバーの待ち受けポート。Cloud Run は PORT を注入する。
	Port string
	// GCPProjectID は Vertex AI を呼ぶ Google Cloud プロジェクトID。
	GCPProjectID string
	// VertexLocation は Vertex AI のリージョン（例: us-central1, asia-northeast1）。
	VertexLocation string
	// GeminiModel は使用する Gemini モデル名。
	GeminiModel string
}

// Load は環境変数から設定を読み込む。
func Load() *Config {
	return &Config{
		Port:           getEnv("PORT", "8080"),
		GCPProjectID:   getEnv("GCP_PROJECT_ID", ""),
		VertexLocation: getEnv("VERTEX_LOCATION", "us-central1"),
		GeminiModel:    getEnv("GEMINI_MODEL", "gemini-2.5-flash"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
