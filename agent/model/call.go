package model

import (
	"errors"
	"time"
)

// AllowedBundleIDs は VoIP push の宛先として許可する bundle ID。
// apns-topic は "{bundleId}.voip" になる。
var AllowedBundleIDs = map[string]bool{
	"com.swiswiswift.zuntalk":     true, // Production
	"com.swiswiswift.zuntalk.dev": true, // Development
}

// APNs 環境。
const (
	APNSEnvSandbox    = "sandbox"
	APNSEnvProduction = "production"
)

// 予約の状態遷移: scheduled → sending → sent | failed。他に canceled / missed。
const (
	CallStatusScheduled = "scheduled"
	CallStatusSending   = "sending"
	CallStatusSent      = "sent"
	CallStatusFailed    = "failed"
	CallStatusCanceled  = "canceled"
	CallStatusMissed    = "missed"
)

const (
	// MaxPendingCallsPerDevice は1端末が同時に持てる予約数の上限。
	// UX をシンプルに保つため1件のみ（変更したい場合はキャンセルして取り直す）。
	MaxPendingCallsPerDevice = 1
	// MaxScheduleAhead は予約可能な未来の上限。
	MaxScheduleAhead = 30 * 24 * time.Hour
)

// RegisterDeviceRequest は PUT /devices のリクエスト。
type RegisterDeviceRequest struct {
	// DeviceID はアプリが生成し Keychain に保持する UUID。
	DeviceID string `json:"deviceId"`
	// VoIPToken は PKPushRegistry から得た hex トークン。
	VoIPToken string `json:"voipToken"`
	// APNSEnv は "sandbox"（Debugビルド）| "production"。
	APNSEnv string `json:"apnsEnv"`
	// BundleID はアプリの bundle identifier。
	BundleID string `json:"bundleId"`
}

// Validate はリクエストの内容を検証する。
func (r *RegisterDeviceRequest) Validate() error {
	if r.DeviceID == "" || r.VoIPToken == "" {
		return errors.New("deviceId and voipToken are required")
	}
	if r.APNSEnv != APNSEnvSandbox && r.APNSEnv != APNSEnvProduction {
		return errors.New("apnsEnv must be sandbox or production")
	}
	if !AllowedBundleIDs[r.BundleID] {
		return errors.New("bundleId is not allowed")
	}
	return nil
}

// CreateCallRequest は POST /calls のリクエスト。
type CreateCallRequest struct {
	DeviceID string `json:"deviceId"`
	// ScheduledAt は RFC3339（例: "2026-07-08T22:30:00+09:00"）。サーバーは UTC で保存する。
	ScheduledAt string `json:"scheduledAt"`
}

// Validate はリクエストを検証し、パース済みの予約時刻（UTC）を返す。
func (r *CreateCallRequest) Validate(now time.Time) (time.Time, error) {
	if r.DeviceID == "" {
		return time.Time{}, errors.New("deviceId is required")
	}
	at, err := time.Parse(time.RFC3339, r.ScheduledAt)
	if err != nil {
		return time.Time{}, errors.New("scheduledAt must be RFC3339")
	}
	at = at.UTC()
	if at.Before(now) {
		return time.Time{}, errors.New("scheduledAt must be in the future")
	}
	if at.After(now.Add(MaxScheduleAhead)) {
		return time.Time{}, errors.New("scheduledAt is too far in the future")
	}
	return at, nil
}

// ScheduledCallResponse は予約1件のレスポンス表現。
type ScheduledCallResponse struct {
	ID          string `json:"id"`
	DeviceID    string `json:"deviceId"`
	ScheduledAt string `json:"scheduledAt"` // RFC3339 (UTC)
	Status      string `json:"status"`
}

// ListCallsResponse は GET /calls のレスポンス。
type ListCallsResponse struct {
	Calls []ScheduledCallResponse `json:"calls"`
}

// DispatchResponse は POST /internal/dispatch のレスポンス（可観測性用）。
type DispatchResponse struct {
	Dispatched int `json:"dispatched"`
	Failed     int `json:"failed"`
	Missed     int `json:"missed"`
}
