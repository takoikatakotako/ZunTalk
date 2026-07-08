package handler

import (
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/takoikatakotako/ZunTalk/agent/model"
	"github.com/takoikatakotako/ZunTalk/agent/orchestrator"
	"github.com/takoikatakotako/ZunTalk/agent/store"
)

// jst は利用回数の日次リセット境界（日本時間の0時）。
var jst = time.FixedZone("JST", 9*60*60)

// AgentHandler は /agent と /health を処理する。
type AgentHandler struct {
	orch *orchestrator.Orchestrator
	// store は利用回数制限のカウンタ保存先。nil なら制限しない（ローカル開発用）。
	store *store.Store
	// dailyLimit は端末ごとの1日の /agent 呼び出し上限。0以下なら制限しない。
	dailyLimit int
}

// NewAgentHandler は AgentHandler を生成する。
func NewAgentHandler(o *orchestrator.Orchestrator, s *store.Store, dailyLimit int) *AgentHandler {
	return &AgentHandler{orch: o, store: s, dailyLimit: dailyLimit}
}

// checkRateLimit は端末ごとの日次利用回数を加算し、上限超過なら false を返す。
// カウンタの障害でエージェントを止めないため、エラー時は許可に倒す。
func (h *AgentHandler) checkRateLimit(c echo.Context, deviceID string) bool {
	if h.store == nil || h.dailyLimit <= 0 {
		return true
	}
	deviceID = normalizeAgentDeviceID(deviceID)
	day := time.Now().In(jst).Format("2006-01-02")
	count, err := h.store.IncrementAgentUsage(c.Request().Context(), deviceID, day)
	if err != nil {
		slog.Error("Failed to count agent usage", "deviceId", deviceID, "error", err)
		return true
	}
	if count > int64(h.dailyLimit) {
		slog.Warn("Agent daily limit exceeded", "deviceId", deviceID, "count", count)
		return false
	}
	return true
}

// normalizeAgentDeviceID は deviceID を Firestore のドキュメントID として安全な形に正規化する。
// 正規のクライアントは Keychain の UUID を送るため、英数字とハイフン・アンダースコア以外を
// 含むものや長すぎるものは不正値とみなして匿名バケットに落とす。
func normalizeAgentDeviceID(deviceID string) string {
	deviceID = strings.TrimSpace(deviceID)
	if deviceID == "" || len(deviceID) > 64 {
		return "anonymous"
	}
	for _, r := range deviceID {
		isAlnum := (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9')
		if !isAlnum && r != '-' && r != '_' {
			return "anonymous"
		}
	}
	return deviceID
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

	// 端末ごとの日次利用回数制限（Vertex AI のコスト保護）。
	// カウントは1巡目のみ。2巡目（ツール実行結果あり）を対象にすると
	// 上限の境界で会話が途中で打ち切られてしまうため、常に通す。
	if len(req.Results) == 0 && !h.checkRateLimit(c, req.DeviceID) {
		return c.JSON(http.StatusTooManyRequests, model.ErrorResponse{
			Code:    "RATE_LIMITED",
			Message: "今日はもうたくさんお話ししたのだ。また明日お話ししてほしいのだ〜",
		})
	}

	ctx := c.Request().Context()

	// 2巡目以降: 端末でのツール実行結果が来ている → 最終応答を生成。
	if len(req.Results) > 0 {
		reply, emotion, err := h.orch.Respond(ctx, req.Message, req.Results)
		if err != nil {
			slog.Error("Failed to respond", "error", err)
			return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
				Code:    "INTERNAL_ERROR",
				Message: "応答生成に失敗しました",
			})
		}
		return c.JSON(http.StatusOK, model.AgentResponse{
			Type:    model.ResponseTypeFinal,
			Reply:   reply,
			Emotion: emotion,
		})
	}

	// 1巡目: 計画を立てる。
	plan, err := h.orch.Plan(ctx, req.Message, req.Capabilities)
	if err != nil {
		slog.Error("Failed to plan", "error", err)
		return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Code:    "INTERNAL_ERROR",
			Message: "計画生成に失敗しました",
		})
	}

	// ツール不要（雑談など）→ そのまま最終応答。
	if len(plan) == 0 {
		reply, emotion, err := h.orch.Respond(ctx, req.Message, nil)
		if err != nil {
			slog.Error("Failed to respond", "error", err)
			return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
				Code:    "INTERNAL_ERROR",
				Message: "応答生成に失敗しました",
			})
		}
		return c.JSON(http.StatusOK, model.AgentResponse{
			Type:    model.ResponseTypeFinal,
			Reply:   reply,
			Emotion: emotion,
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
