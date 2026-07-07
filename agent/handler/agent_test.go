package handler

import (
	"strings"
	"testing"
)

func TestNormalizeAgentDeviceID(t *testing.T) {
	tests := []struct {
		name     string
		deviceID string
		want     string
	}{
		{name: "uuid is kept as-is", deviceID: "1B9D6BCD-BBFD-4B2D-9B5D-AB8DFBBD4BED", want: "1B9D6BCD-BBFD-4B2D-9B5D-AB8DFBBD4BED"},
		{name: "surrounding spaces are trimmed", deviceID: "  abc-123  ", want: "abc-123"},
		{name: "empty falls back to anonymous", deviceID: "", want: "anonymous"},
		{name: "slash is rejected", deviceID: "a/b", want: "anonymous"},
		{name: "dot-only id is rejected", deviceID: "..", want: "anonymous"},
		{name: "multibyte is rejected", deviceID: "ずんだもん", want: "anonymous"},
		{name: "too long id is rejected", deviceID: strings.Repeat("a", 65), want: "anonymous"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := normalizeAgentDeviceID(tt.deviceID); got != tt.want {
				t.Fatalf("normalizeAgentDeviceID(%q) = %q, want %q", tt.deviceID, got, tt.want)
			}
		})
	}
}
