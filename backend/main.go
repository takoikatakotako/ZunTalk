package main

import (
	"log"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/takoikatakotako/ZunTalk/backend/config"
	"github.com/takoikatakotako/ZunTalk/backend/handler"
	"github.com/takoikatakotako/ZunTalk/backend/service"
)

func main() {
	// 設定の読み込み
	cfg := config.Load()

	if cfg.OpenAIAPIKey == "" {
		log.Fatal("OPENAI_API_KEY environment variable is required")
	}

	// Echoインスタンスの作成
	e := setupServer(cfg)

	// サーバー起動
	log.Printf("Starting server on port %s", cfg.Port)
	if err := e.Start(":" + cfg.Port); err != nil {
		log.Fatal(err)
	}
}

func setupServer(cfg *config.Config) *echo.Echo {
	e := echo.New()

	// ミドルウェアの設定
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// サービスの初期化
	openAIService := service.NewOpenAIService(cfg.OpenAIAPIKey)

	// ハンドラーの初期化
	chatHandler := handler.NewChatHandler(openAIService)

	// ルーティング
	e.POST("/api/chat", chatHandler.HandleChat)
	e.GET("/health", chatHandler.HandleHealth)

	return e
}
