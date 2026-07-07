package orchestrator

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/takoikatakotako/ZunTalk/agent/model"
	"google.golang.org/genai"
)

// capabilityDescriptions は planner のプロンプトに載せるツール説明。
var capabilityDescriptions = map[model.Capability]string{
	model.CapabilityCalendar: "カレンダーの予定を調べる（端末の標準カレンダー）",
	model.CapabilityGmail:    "Gmailのメールを調べる",
}

// allCapabilities は既定のツール一覧（クライアントが capabilities を送らない場合の後方互換）。
var allCapabilities = []model.Capability{model.CapabilityCalendar, model.CapabilityGmail}

// normalizeCapabilities はクライアント申告の capabilities を検証して返す。
// 空・欠落なら全ツール、未知の値は除外する。
func normalizeCapabilities(requested []model.Capability) []model.Capability {
	if len(requested) == 0 {
		return allCapabilities
	}
	capabilities := make([]model.Capability, 0, len(requested))
	for _, c := range requested {
		if _, ok := capabilityDescriptions[c]; ok {
			capabilities = append(capabilities, c)
		}
	}
	if len(capabilities) == 0 {
		return allCapabilities
	}
	return capabilities
}

// plannerPrompt は利用可能ツールに応じたシステムプロンプトを組み立てる。
func plannerPrompt(capabilities []model.Capability) string {
	var tools strings.Builder
	for _, c := range capabilities {
		fmt.Fprintf(&tools, "- %s: %s\n", c, capabilityDescriptions[c])
	}
	return fmt.Sprintf(`あなたはずんだもんの「司令塔」エージェントなのだ。
ユーザーの発話を読み、必要な情報源（ツール）を選んで実行計画を立てる。

利用できるツール:
%s
ルール:
- 上に挙げたツールで調べられない話題や、雑談だけのときは steps を空配列にする。
- 各ステップの query には、そのツールで具体的に何を調べるべきかを日本語で書く。
- 必要なツールだけを選ぶ。複数必要なら複数入れてよい。`, tools.String())
}

// planSchema は planner の出力（steps 配列）を強制する JSON スキーマ。
// capability は利用可能ツールの Enum に制約する。
func planSchema(capabilities []model.Capability) *genai.Schema {
	enum := make([]string, 0, len(capabilities))
	for _, c := range capabilities {
		enum = append(enum, string(c))
	}
	return &genai.Schema{
		Type: genai.TypeObject,
		Properties: map[string]*genai.Schema{
			"steps": {
				Type: genai.TypeArray,
				Items: &genai.Schema{
					Type: genai.TypeObject,
					Properties: map[string]*genai.Schema{
						"capability": {
							Type: genai.TypeString,
							Enum: enum,
						},
						"query":  {Type: genai.TypeString},
						"reason": {Type: genai.TypeString},
					},
					Required: []string{"capability", "query"},
				},
			},
		},
		Required: []string{"steps"},
	}
}

// Plan はユーザー発話から「端末に実行させるツール計画」を立てる。
// requested はクライアントが利用できるツールの申告（空なら全ツール）。
func (o *Orchestrator) Plan(ctx context.Context, userInput string, requested []model.Capability) ([]model.PlanStep, error) {
	capabilities := normalizeCapabilities(requested)

	raw, err := o.llm.GenerateJSON(ctx, plannerPrompt(capabilities), userInput, planSchema(capabilities))
	if err != nil {
		return nil, err
	}

	var out struct {
		Steps []model.PlanStep `json:"steps"`
	}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return nil, fmt.Errorf("計画のパースに失敗: %w (raw=%s)", err, raw)
	}

	// 利用可能ツール以外の capability は念のため除外する。
	allowed := make(map[model.Capability]bool, len(capabilities))
	for _, c := range capabilities {
		allowed[c] = true
	}
	steps := make([]model.PlanStep, 0, len(out.Steps))
	for _, s := range out.Steps {
		if allowed[s.Capability] {
			steps = append(steps, s)
		}
	}
	return steps, nil
}
