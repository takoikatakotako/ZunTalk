package orchestrator

import (
	"strings"
	"testing"

	"github.com/takoikatakotako/ZunTalk/agent/model"
)

func TestNormalizeCapabilities(t *testing.T) {
	tests := []struct {
		name      string
		requested []model.Capability
		want      []model.Capability
	}{
		{
			name:      "empty falls back to all capabilities",
			requested: nil,
			want:      []model.Capability{model.CapabilityCalendar, model.CapabilityGmail},
		},
		{
			name:      "unknown values are removed",
			requested: []model.Capability{model.Capability("unknown"), model.CapabilityCalendar},
			want:      []model.Capability{model.CapabilityCalendar},
		},
		{
			name:      "only unknown values fall back to all capabilities",
			requested: []model.Capability{model.Capability("unknown")},
			want:      []model.Capability{model.CapabilityCalendar, model.CapabilityGmail},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := normalizeCapabilities(tt.requested)
			if len(got) != len(tt.want) {
				t.Fatalf("len = %d, want %d (%v)", len(got), len(tt.want), got)
			}
			for i := range got {
				if got[i] != tt.want[i] {
					t.Fatalf("capability[%d] = %q, want %q", i, got[i], tt.want[i])
				}
			}
		})
	}
}

func TestPlannerPromptUsesRequestedCapabilities(t *testing.T) {
	prompt := plannerPrompt([]model.Capability{model.CapabilityCalendar})

	if !strings.Contains(prompt, "- calendar:") {
		t.Fatal("prompt should include calendar capability")
	}
	if strings.Contains(prompt, "- gmail:") {
		t.Fatal("prompt should not include gmail capability")
	}
	if strings.Contains(prompt, "Googleカレンダー") {
		t.Fatal("prompt should not mention Google calendar")
	}
}

func TestPlanSchemaUsesRequestedCapabilities(t *testing.T) {
	schema := planSchema([]model.Capability{model.CapabilityCalendar})
	capabilitySchema := schema.Properties["steps"].Items.Properties["capability"]

	if len(capabilitySchema.Enum) != 1 {
		t.Fatalf("enum len = %d, want 1 (%v)", len(capabilitySchema.Enum), capabilitySchema.Enum)
	}
	if capabilitySchema.Enum[0] != string(model.CapabilityCalendar) {
		t.Fatalf("enum[0] = %q, want %q", capabilitySchema.Enum[0], model.CapabilityCalendar)
	}
}
