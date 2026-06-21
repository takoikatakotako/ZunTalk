package handler

import (
	"log/slog"
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/takoikatakotako/ZunTalk/agent/model"
	"github.com/takoikatakotako/ZunTalk/agent/orchestrator"
)

// AgentHandler は /agent と /health を処理する。
type AgentHandler struct {
	orch *orchestrator.Orchestrator
}

// NewAgentHandler は AgentHandler を生成する。
func NewAgentHandler(o *orchestrator.Orchestrator) *AgentHandler {
	return &AgentHandler{orch: o}
}

// HandleAgent はステートレスなエージェント往復を処理する。
//   - results あり → responder で最終応答を返す
//   - results なし → planner で計画を立て、ツールがあれば端末に実行依頼、なければ即応答
func (h *AgentHandler) HandleAgent(c echo.Context) error {
	var req model.AgentRequest
	if err := c.Bind(&req); err != nil {
		slog.Warn("Failed to bind request", "error", err)
		return c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Code:    "INVALID_REQUEST",
			Message: "リクエストが不正です",
		})
	}
	if req.Message == "" {
		slog.Warn("Empty message in request")
		return c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Code:    "INVALID_REQUEST",
			Message: "メッセージが空です",
		})
	}

	ctx := c.Request().Context()

	// 2巡目以降: 端末でのツール実行結果が来ている → 最終応答を生成。
	if len(req.Results) > 0 {
		reply, err := h.orch.Respond(ctx, req.Message, req.Results)
		if err != nil {
			slog.Error("Failed to respond", "error", err)
			return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
				Code:    "INTERNAL_ERROR",
				Message: "応答生成に失敗しました",
			})
		}
		return c.JSON(http.StatusOK, model.AgentResponse{
			Type:  model.ResponseTypeFinal,
			Reply: reply,
		})
	}

	// 1巡目: 計画を立てる。
	plan, err := h.orch.Plan(ctx, req.Message)
	if err != nil {
		slog.Error("Failed to plan", "error", err)
		return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Code:    "INTERNAL_ERROR",
			Message: "計画生成に失敗しました",
		})
	}

	// ツール不要（雑談など）→ そのまま最終応答。
	if len(plan) == 0 {
		reply, err := h.orch.Respond(ctx, req.Message, nil)
		if err != nil {
			slog.Error("Failed to respond", "error", err)
			return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
				Code:    "INTERNAL_ERROR",
				Message: "応答生成に失敗しました",
			})
		}
		return c.JSON(http.StatusOK, model.AgentResponse{
			Type:  model.ResponseTypeFinal,
			Reply: reply,
		})
	}

	// 端末にツール実行を依頼する。
	return c.JSON(http.StatusOK, model.AgentResponse{
		Type: model.ResponseTypeToolCalls,
		Plan: plan,
	})
}

// HandleHealth はヘルスチェック。
func (h *AgentHandler) HandleHealth(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]string{
		"status": "ok",
	})
}
