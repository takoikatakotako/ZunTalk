package main

import (
	"context"
	"log"

	"github.com/joho/godotenv"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/takoikatakotako/ZunTalk/agent/config"
	"github.com/takoikatakotako/ZunTalk/agent/handler"
	"github.com/takoikatakotako/ZunTalk/agent/llm"
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

	e := setupServer(agentHandler)

	log.Printf("Starting agent server on port %s", cfg.Port)
	if err := e.Start(":" + cfg.Port); err != nil {
		log.Fatal(err)
	}
}

func setupServer(h *handler.AgentHandler) *echo.Echo {
	e := echo.New()

	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	e.POST("/agent", h.HandleAgent)
	e.GET("/health", h.HandleHealth)
	e.HEAD("/health", h.HandleHealth)

	return e
}
