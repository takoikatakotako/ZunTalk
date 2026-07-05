package handler

import (
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/takoikatakotako/ZunTalk/agent/apns"
	"github.com/takoikatakotako/ZunTalk/agent/model"
	"github.com/takoikatakotako/ZunTalk/agent/store"
)

// DispatchHandler は Cloud Scheduler から毎分呼ばれ、
// 期限が到来した予約に VoIP push を送る。
type DispatchHandler struct {
	store *store.Store
	apns  *apns.Client // APNs 未設定（ローカル等）なら nil
}

// NewDispatchHandler は DispatchHandler を生成する。
func NewDispatchHandler(s *store.Store, a *apns.Client) *DispatchHandler {
	return &DispatchHandler{store: s, apns: a}
}

// HandleDispatch は POST /internal/dispatch。
// 1件の失敗で全体を落とさず、送れるものはすべて送る。
func (h *DispatchHandler) HandleDispatch(c echo.Context) error {
	if h.apns == nil {
		slog.Warn("Dispatch requested but APNs is not configured")
		return c.JSON(http.StatusServiceUnavailable, model.ErrorResponse{
			Code:    "APNS_NOT_CONFIGURED",
			Message: "APNs credentials are not configured",
		})
	}

	ctx := c.Request().Context()
	now := time.Now().UTC()
	res := model.DispatchResponse{}

	// 猶予時間を過ぎた古い予約は missed に掃き出す
	missed, err := h.store.MarkMissedCalls(ctx, now)
	if err != nil {
		slog.Error("Failed to mark missed calls", "error", err)
	}
	res.Missed = missed

	// 期限到来分を claim（多重実行しても claim できた実行だけが送る）
	calls, err := h.store.ClaimDueCalls(ctx, now)
	if err != nil {
		slog.Error("Failed to claim due calls", "error", err)
		return c.JSON(http.StatusInternalServerError, model.ErrorResponse{
			Code:    "INTERNAL_ERROR",
			Message: "予約の取得に失敗しました",
		})
	}

	for _, call := range calls {
		if err := h.sendCall(c, call); err != nil {
			slog.Error("Failed to send call push", "callId", call.ID, "deviceId", call.DeviceID, "error", err)
			_ = h.store.MarkCallResult(ctx, call.ID, model.CallStatusFailed, err.Error())
			res.Failed++
			continue
		}
		slog.Info("Call push sent", "callId", call.ID, "deviceId", call.DeviceID)
		_ = h.store.MarkCallResult(ctx, call.ID, model.CallStatusSent, "")
		res.Dispatched++
	}

	return c.JSON(http.StatusOK, res)
}

func (h *DispatchHandler) sendCall(c echo.Context, call store.ScheduledCall) error {
	ctx := c.Request().Context()

	device, err := h.store.GetDevice(ctx, call.DeviceID)
	if err != nil {
		return fmt.Errorf("device lookup failed: %w", err)
	}
	if device.InvalidatedAt != nil {
		return errors.New("device token is invalidated")
	}

	topic := device.BundleID + ".voip"
	payload := apns.NewVoIPPayload(call.ID)
	err = h.apns.Send(ctx, device.VoIPToken, apns.Env(device.APNSEnv), topic, payload)

	// BadDeviceToken = トークンと環境の不一致。VoIP push は sandbox ゲートウェイが
	// 不安定なことで知られる（development ビルドのトークンが production 側でしか
	// 通らないケースがある）ため、逆の環境で再送し、通ったらその環境を学習する。
	if errors.Is(err, apns.ErrBadDeviceToken) {
		fallbackEnv := apns.EnvProduction
		if apns.Env(device.APNSEnv) == apns.EnvProduction {
			fallbackEnv = apns.EnvSandbox
		}
		slog.Warn("BadDeviceToken; retrying with fallback env",
			"deviceId", call.DeviceID, "registeredEnv", device.APNSEnv, "fallbackEnv", fallbackEnv)

		if retryErr := h.apns.Send(ctx, device.VoIPToken, fallbackEnv, topic, payload); retryErr == nil {
			if updateErr := h.store.UpdateDeviceAPNSEnv(ctx, call.DeviceID, string(fallbackEnv)); updateErr != nil {
				slog.Error("Failed to update device apnsEnv", "deviceId", call.DeviceID, "error", updateErr)
			}
			slog.Info("Fallback env succeeded; device apnsEnv updated",
				"deviceId", call.DeviceID, "apnsEnv", fallbackEnv)
			return nil
		}
		return err
	}

	if errors.Is(err, apns.ErrUnregistered) {
		// トークン失効 → 端末を無効化して以後の送信を止める
		if markErr := h.store.MarkDeviceInvalid(ctx, call.DeviceID); markErr != nil {
			slog.Error("Failed to mark device invalid", "deviceId", call.DeviceID, "error", markErr)
		}
		return err
	}
	return err
}
