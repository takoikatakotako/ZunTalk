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
	"github.com/takoikatakotako/ZunTalk/agent/apns"
	"github.com/takoikatakotako/ZunTalk/agent/config"
	"github.com/takoikatakotako/ZunTalk/agent/handler"
	"github.com/takoikatakotako/ZunTalk/agent/llm"
	appmiddleware "github.com/takoikatakotako/ZunTalk/agent/middleware"
	"github.com/takoikatakotako/ZunTalk/agent/model"
	"github.com/takoikatakotako/ZunTalk/agent/orchestrator"
	"github.com/takoikatakotako/ZunTalk/agent/store"
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

	// Firestore（電話予約・端末トークンの保存先）を初期化（ADC でキーレス認証）。
	st, err := store.New(ctx, cfg.GCPProjectID, cfg.FirestoreDatabase)
	if err != nil {
		log.Fatalf("failed to init Firestore client: %v", err)
	}
	defer st.Close()
	agentHandler := handler.NewAgentHandler(orch, st, cfg.AgentDailyLimit)

	// APNs クライアント。未設定・不正なら nil にして /internal/dispatch だけ 503 を返す
	//（キーの不備で /agent まで落とさない）。
	var apnsClient *apns.Client
	if cfg.APNSAuthKey != "" && cfg.APNSKeyID != "" && cfg.APNSTeamID != "" {
		apnsClient, err = apns.New([]byte(cfg.APNSAuthKey), cfg.APNSKeyID, cfg.APNSTeamID)
		if err != nil {
			slog.Error("failed to init APNs client; /internal/dispatch will return 503", "error", err)
		}
	} else {
		slog.Warn("APNs credentials are not configured; /internal/dispatch will return 503")
	}

	deviceHandler := handler.NewDeviceHandler(st)
	callHandler := handler.NewCallHandler(st)
	dispatchHandler := handler.NewDispatchHandler(st, apnsClient)

	if cfg.APIKey == "" {
		slog.Warn("AGENT_API_KEY is empty; /agent API key verification is DISABLED (local dev only)")
	}

	e := setupServer(agentHandler, deviceHandler, callHandler, dispatchHandler, cfg)

	log.Printf("Starting agent server on port %s", cfg.Port)
	if err := e.Start(":" + cfg.Port); err != nil {
		log.Fatal(err)
	}
}

func setupServer(
	h *handler.AgentHandler,
	deviceHandler *handler.DeviceHandler,
	callHandler *handler.CallHandler,
	dispatchHandler *handler.DispatchHandler,
	cfg *config.Config,
) *echo.Echo {
	e := echo.New()

	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// /health は鍵不要（Cloud Run のヘルスチェック用）。
	e.GET("/health", h.HandleHealth)
	e.HEAD("/health", h.HandleHealth)

	// アプリ向け API は X-Api-Key 検証を必須にする（鍵が設定されている場合）。
	apiKey := apiKeyMiddleware(cfg.APIKey)
	e.POST("/agent", h.HandleAgent, apiKey)
	e.PUT("/devices", deviceHandler.HandleUpsertDevice, apiKey)
	e.POST("/calls", callHandler.HandleCreateCall, apiKey)
	e.GET("/calls", callHandler.HandleListCalls, apiKey)
	e.DELETE("/calls/:id", callHandler.HandleCancelCall, apiKey)

	// /internal/dispatch は Cloud Scheduler（OIDC）からのみ呼べる。
	e.POST("/internal/dispatch", dispatchHandler.HandleDispatch,
		appmiddleware.SchedulerOIDC(cfg.SchedulerServiceAccount, cfg.DispatchAudience))

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
