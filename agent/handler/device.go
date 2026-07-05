package handler

import (
	"log/slog"
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/takoikatakotako/ZunTalk/agent/model"
	"github.com/takoikatakotako/ZunTalk/agent/store"
)

// DeviceHandler は端末（VoIP トークン）の登録を処理する。
type DeviceHandler struct {
	store *store.Store
}

// NewDeviceHandler は DeviceHandler を生成する。
func NewDeviceHandler(s *store.Store) *DeviceHandler {
	return &DeviceHandler{store: s}
}

// HandleUpsertDevice は PUT /devices。VoIP トークンを登録・更新する（冪等）。
func (h *DeviceHandler) HandleUpsertDevice(c echo.Context) error {
	var req model.RegisterDeviceRequest
	if err := c.Bind(&req); err != nil {
		slog.Warn("Failed to bind device request", "error", err)
		return c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Code:    "INVALID_REQUEST",
			Message: "リクエストが不正です",
		})
	}
	if err := req.Validate(); err != nil {
		slog.Warn("Invalid device request", "error", err)
		return c.JSON(http.StatusBadRequest, model.ErrorResponse{
			Code:    "INVALID_REQUEST",
			Message: err.Error(),
		})
	}

	if err := h.store.UpsertDevice(c.Request().Context(), req.DeviceID, req); err != nil {
		slog.Error("Failed to upsert device", "deviceId", req.DeviceID, "error", err)
		return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Code:    "INTERNAL_ERROR",
			Message: "端末の登録に失敗しました",
		})
	}
	slog.Info("Device registered", "deviceId", req.DeviceID, "apnsEnv", req.APNSEnv, "bundleId", req.BundleID)
	return c.NoContent(http.StatusNoContent)
}
