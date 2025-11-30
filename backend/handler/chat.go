package handler

import (
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/takoikatakotako/ZunTalk/backend/model"
	"github.com/takoikatakotako/ZunTalk/backend/service"
)

type ChatHandler struct {
	openAIService *service.OpenAIService
}

func NewChatHandler(openAIService *service.OpenAIService) *ChatHandler {
	return &ChatHandler{
		openAIService: openAIService,
	}
}

func (h *ChatHandler) HandleChat(c echo.Context) error {
	var req model.ChatRequest

	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Code:    "INVALID_REQUEST",
			Message: "リクエストが不正です",
		})
	}

	// バリデーション
	if len(req.Messages) == 0 {
		return c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Code:    "INVALID_REQUEST",
			Message: "メッセージが空です",
		})
	}

	// OpenAI APIを呼び出し
	resp, err := h.openAIService.CreateChatCompletion(&req)
	if err != nil {
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
