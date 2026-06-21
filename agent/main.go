package main

import (
	"context"
	"crypto/subtle"
	"log"
	"log/slog"
	"net/http"

	"github.com/joho/godotenv"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/takoikatakotako/ZunTalk/agent/config"
	"github.com/takoikatakotako/ZunTalk/agent/handler"
	"github.com/takoikatakotako/ZunTalk/agent/llm"
	"github.com/takoikatakotako/ZunTalk/agent/model"
	"github.com/takoikatakotako/ZunTalk/agent/orchestrator"
)

func main() {
	// .env を読み込み（本番では環境変数が直接設定されるためエラーは無視）。
	_ = godotenv.Load()

	cfg := config.Load()
	if cfg.GCPProjectID == "" {
		log.Fatal("GCP_PROJECT_ID environment variable is required")
	}

	ctx := context.Background()

	// Vertex AI(Gemini) クライアントを初期化（ADC でキーレス認証）。
	gemini, err := llm.NewGemini(ctx, cfg.GCPProjectID, cfg.VertexLocation, cfg.GeminiModel)
	if err != nil {
		log.Fatalf("failed to init Gemini client: %v", err)
	}

	orch := orchestrator.New(gemini)
	agentHandler := handler.NewAgentHandler(orch)

	if cfg.APIKey == "" {
		slog.Warn("AGENT_API_KEY is empty; /agent API key verification is DISABLED (local dev only)")
	}

	e := setupServer(agentHandler, cfg.APIKey)

	log.Printf("Starting agent server on port %s", cfg.Port)
	if err := e.Start(":" + cfg.Port); err != nil {
		log.Fatal(err)
	}
}

func setupServer(h *handler.AgentHandler, apiKey string) *echo.Echo {
	e := echo.New()

	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// /health は鍵不要（Cloud Run のヘルスチェック用）。
	e.GET("/health", h.HandleHealth)
	e.HEAD("/health", h.HandleHealth)

	// /agent は X-Api-Key 検証を必須にする（鍵が設定されている場合）。
	e.POST("/agent", h.HandleAgent, apiKeyMiddleware(apiKey))

	return e
}

// apiKeyMiddleware は X-Api-Key ヘッダーを共有シークレットと照合する。
// apiKey が空ならローカル開発用に検証をスキップする。
func apiKeyMiddleware(apiKey string) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			if apiKey == "" {
				return next(c)
			}
			// タイミング攻撃を避けるため定数時間比較。
			provided := c.Request().Header.Get("X-Api-Key")
			if subtle.ConstantTimeCompare([]byte(provided), []byte(apiKey)) != 1 {
				slog.Warn("Rejected request with invalid API key")
				return c.JSON(http.StatusUnauthorized, model.ErrorResponse{
					Code:    "UNAUTHORIZED",
					Message: "APIキーが不正です",
				})
			}
			return next(c)
		}
	}
}
