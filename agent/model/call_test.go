package model

import (
	"testing"
	"time"
)

func TestRegisterDeviceRequestValidate(t *testing.T) {
	valid := RegisterDeviceRequest{
		DeviceID:  "device-1",
		VoIPToken: "abc123",
		APNSEnv:   APNSEnvSandbox,
		BundleID:  "com.swiswiswift.zuntalk.dev",
	}
	if err := valid.Validate(); err != nil {
		t.Errorf("valid request should pass: %v", err)
	}

	cases := []struct {
		name   string
		mutate func(*RegisterDeviceRequest)
	}{
		{"empty deviceId", func(r *RegisterDeviceRequest) { r.DeviceID = "" }},
		{"empty voipToken", func(r *RegisterDeviceRequest) { r.VoIPToken = "" }},
		{"invalid apnsEnv", func(r *RegisterDeviceRequest) { r.APNSEnv = "staging" }},
		{"disallowed bundleId", func(r *RegisterDeviceRequest) { r.BundleID = "com.example.evil" }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req := valid
			tc.mutate(&req)
			if err := req.Validate(); err == nil {
				t.Error("expected validation error, got nil")
			}
		})
	}
}

func TestCreateCallRequestValidate(t *testing.T) {
	now := time.Date(2026, 7, 5, 12, 0, 0, 0, time.UTC)

	t.Run("valid future time is normalized to UTC", func(t *testing.T) {
		req := CreateCallRequest{DeviceID: "device-1", ScheduledAt: "2026-07-05T22:30:00+09:00"}
		at, err := req.Validate(now)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		want := time.Date(2026, 7, 5, 13, 30, 0, 0, time.UTC)
		if !at.Equal(want) {
			t.Errorf("got %v, want %v", at, want)
		}
		if at.Location() != time.UTC {
			t.Errorf("expected UTC, got %v", at.Location())
		}
	})

	cases := []struct {
		name string
		req  CreateCallRequest
	}{
		{"empty deviceId", CreateCallRequest{ScheduledAt: "2026-07-05T13:00:00Z"}},
		{"not RFC3339", CreateCallRequest{DeviceID: "d", ScheduledAt: "2026/07/05 13:00"}},
		{"in the past", CreateCallRequest{DeviceID: "d", ScheduledAt: "2026-07-05T11:59:00Z"}},
		{"too far ahead", CreateCallRequest{DeviceID: "d", ScheduledAt: "2026-09-01T00:00:00Z"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if _, err := tc.req.Validate(now); err == nil {
				t.Error("expected validation error, got nil")
			}
		})
	}
}
