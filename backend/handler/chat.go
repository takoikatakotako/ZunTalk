package handler

import (
	"log/slog"
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/takoikatakotako/ZunTalk/backend/config"
	"github.com/takoikatakotako/ZunTalk/backend/model"
	"github.com/takoikatakotako/ZunTalk/backend/service"
)

type ChatHandler struct {
	openAIService *service.OpenAIService
	config        *config.Config
}

func NewChatHandler(openAIService *service.OpenAIService, cfg *config.Config) *ChatHandler {
	return &ChatHandler{
		openAIService: openAIService,
		config:        cfg,
	}
}

func (h *ChatHandler) HandleChat(c echo.Context) error {
	var req model.ChatRequest

	if err := c.Bind(&req); err != nil {
		slog.Warn("Failed to bind request", "error", err)
		return c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Code:    "INVALID_REQUEST",
			Message: "リクエストが不正です",
		})
	}

	// バリデーション
	if len(req.Messages) == 0 {
		slog.Warn("Empty messages in request")
		return c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Code:    "INVALID_REQUEST",
			Message: "メッセージが空です",
		})
	}

	// OpenAI APIを呼び出し
	resp, err := h.openAIService.CreateChatCompletion(&req)
	if err != nil {
		slog.Error("Failed to create chat completion", "error", err)
		return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Code:    "INTERNAL_ERROR",
			Message: "チャット生成に失敗しました",
		})
	}

	return c.JSON(http.StatusOK, resp)
}

func (h *ChatHandler) HandleHealth(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]string{
		"status": "ok",
	})
}

func (h *ChatHandler) HandleRoot(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]string{
		"message": "running",
	})
}

func (h *ChatHandler) HandleInfo(c echo.Context) error {
	response := model.AppConfigResponse{
		Maintenance:    h.config.Maintenance,
		MinimumVersion: h.config.MinimumVersion,
	}

	return c.JSON(http.StatusOK, response)
}

func (h *ChatHandler) HandleError(c echo.Context) error {
	slog.Error("Test error for Slack notification", "endpoint", "/api/error", "message", "This is a test error")
	return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
		Code:    "TEST_ERROR",
		Message: "テストエラーです",
	})
}
