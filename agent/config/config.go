package config

import (
	"os"
	"strconv"
)

// Config はエージェントサーバーの設定。環境変数から読み込む。
type Config struct {
	// Port は HTTP サーバーの待ち受けポート。Cloud Run は PORT を注入する。
	Port string
	// GCPProjectID は Vertex AI を呼ぶ Google Cloud プロジェクトID。
	GCPProjectID string
	// FirestoreDatabase は接続する Firestore データベースID。
	// dev/prod で分離するために使う。空・未設定なら "(default)"。
	FirestoreDatabase string
	// VertexLocation は Vertex AI のリージョン（例: us-central1, asia-northeast1）。
	VertexLocation string
	// GeminiModel は使用する Gemini モデル名。
	GeminiModel string
	// APIKey は /agent を保護する共有シークレット（X-Api-Key ヘッダーと照合）。
	// 空の場合はローカル開発用に検証をスキップする。
	APIKey string
	// AgentDailyLimit は deviceId ごとの /agent 日次呼び出し上限。0以下なら制限しない。
	AgentDailyLimit int

	// APNSKeyID は APNs Auth Key (.p8) の Key ID。
	APNSKeyID string
	// APNSTeamID は Apple Developer の Team ID。
	APNSTeamID string
	// APNSAuthKey は .p8 ファイルの中身（PEM）。Secret Manager から環境変数で注入する。
	// 空の場合、VoIP push（/internal/dispatch）は 503 を返す。
	APNSAuthKey string
	// SchedulerServiceAccount は /internal/dispatch の呼び出しを許可する
	// Cloud Scheduler のサービスアカウント email。空なら OIDC 検証をスキップ（ローカル開発用）。
	SchedulerServiceAccount string
	// DispatchAudience は Scheduler の OIDC トークンの audience（Cloud Run の URL）。
	DispatchAudience string
}

// Load は環境変数から設定を読み込む。
func Load() *Config {
	return &Config{
		Port:              getEnv("PORT", "8080"),
		GCPProjectID:      getEnv("GCP_PROJECT_ID", ""),
		FirestoreDatabase: getEnv("FIRESTORE_DATABASE", "(default)"),
		VertexLocation:    getEnv("VERTEX_LOCATION", "us-central1"),
		GeminiModel:       getEnv("GEMINI_MODEL", "gemini-2.5-flash"),
		APIKey:            getEnv("AGENT_API_KEY", ""),
		AgentDailyLimit:   getEnvInt("AGENT_DAILY_LIMIT", 50),

		APNSKeyID:               getEnv("APNS_KEY_ID", ""),
		APNSTeamID:              getEnv("APNS_TEAM_ID", ""),
		APNSAuthKey:             getEnv("APNS_AUTH_KEY", ""),
		SchedulerServiceAccount: getEnv("SCHEDULER_SERVICE_ACCOUNT", ""),
		DispatchAudience:        getEnv("DISPATCH_AUDIENCE", ""),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return defaultValue
	}
	return parsed
}
