package handler

import (
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/takoikatakotako/ZunTalk/agent/model"
	"github.com/takoikatakotako/ZunTalk/agent/store"
)

// CallHandler は電話予約の作成・一覧・キャンセルを処理する。
type CallHandler struct {
	store *store.Store
}

// NewCallHandler は CallHandler を生成する。
func NewCallHandler(s *store.Store) *CallHandler {
	return &CallHandler{store: s}
}

// HandleCreateCall は POST /calls。指定時刻の電話を予約する。
func (h *CallHandler) HandleCreateCall(c echo.Context) error {
	var req model.CreateCallRequest
	if err := c.Bind(&req); err != nil {
		slog.Warn("Failed to bind call request", "error", err)
		return c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Code:    "INVALID_REQUEST",
			Message: "リクエストが不正です",
		})
	}
	scheduledAt, err := req.Validate(time.Now())
	if err != nil {
		slog.Warn("Invalid call request", "error", err)
		return c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Code:    "INVALID_REQUEST",
			Message: err.Error(),
		})
	}

	ctx := c.Request().Context()

	// トークン登録済みの端末以外は予約できない
	if _, err := h.store.GetDevice(ctx, req.DeviceID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return c.JSON(http.StatusBadRequest, model.ErrorResponse{
				Code:    "DEVICE_NOT_REGISTERED",
				Message: "端末が登録されていません",
			})
		}
		slog.Error("Failed to get device", "deviceId", req.DeviceID, "error", err)
		return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Code:    "INTERNAL_ERROR",
			Message: "予約の作成に失敗しました",
		})
	}

	call, err := h.store.CreateCall(ctx, req.DeviceID, scheduledAt)
	if err != nil {
		if errors.Is(err, store.ErrLimitExceeded) {
			return c.JSON(http.StatusBadRequest, model.ErrorResponse{
				Code:    "LIMIT_EXCEEDED",
				Message: "予約できる件数の上限に達しています",
			})
		}
		slog.Error("Failed to create call", "deviceId", req.DeviceID, "error", err)
		return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Code:    "INTERNAL_ERROR",
			Message: "予約の作成に失敗しました",
		})
	}

	slog.Info("Call scheduled", "callId", call.ID, "deviceId", call.DeviceID, "scheduledAt", call.ScheduledAt)
	return c.JSON(http.StatusCreated, toCallResponse(*call))
}

// HandleListCalls は GET /calls?deviceId=xxx。端末の予約一覧を返す。
func (h *CallHandler) HandleListCalls(c echo.Context) error {
	deviceID := c.QueryParam("deviceId")
	if deviceID == "" {
		return c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Code:    "INVALID_REQUEST",
			Message: "deviceId is required",
		})
	}

	calls, err := h.store.ListCalls(c.Request().Context(), deviceID)
	if err != nil {
		slog.Error("Failed to list calls", "deviceId", deviceID, "error", err)
		return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Code:    "INTERNAL_ERROR",
			Message: "予約一覧の取得に失敗しました",
		})
	}

	res := model.ListCallsResponse{Calls: make([]model.ScheduledCallResponse, 0, len(calls))}
	for _, call := range calls {
		res.Calls = append(res.Calls, toCallResponse(call))
	}
	return c.JSON(http.StatusOK, res)
}

// HandleCancelCall は DELETE /calls/:id?deviceId=xxx。予約をキャンセルする。
func (h *CallHandler) HandleCancelCall(c echo.Context) error {
	callID := c.Param("id")
	deviceID := c.QueryParam("deviceId")
	if callID == "" || deviceID == "" {
		return c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Code:    "INVALID_REQUEST",
			Message: "id and deviceId are required",
		})
	}

	err := h.store.CancelCall(c.Request().Context(), callID, deviceID)
	switch {
	case err == nil:
		slog.Info("Call canceled", "callId", callID, "deviceId", deviceID)
		return c.NoContent(http.StatusNoContent)
	case errors.Is(err, store.ErrNotFound):
		return c.JSON(http.StatusNotFound, model.ErrorResponse{
			Code:    "NOT_FOUND",
			Message: "予約が見つかりません",
		})
	case errors.Is(err, store.ErrForbidden):
		return c.JSON(http.StatusForbidden, model.ErrorResponse{
			Code:    "FORBIDDEN",
			Message: "この予約は操作できません",
		})
	case errors.Is(err, store.ErrConflict):
		return c.JSON(http.StatusConflict, model.ErrorResponse{
			Code:    "CONFLICT",
			Message: "この予約はすでに確定しています",
		})
	default:
		slog.Error("Failed to cancel call", "callId", callID, "error", err)
		return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Code:    "INTERNAL_ERROR",
			Message: "予約のキャンセルに失敗しました",
		})
	}
}

func toCallResponse(call store.ScheduledCall) model.ScheduledCallResponse {
	return model.ScheduledCallResponse{
		ID:          call.ID,
		DeviceID:    call.DeviceID,
		ScheduledAt: call.ScheduledAt.UTC().Format(time.RFC3339),
		Status:      call.Status,
	}
}
