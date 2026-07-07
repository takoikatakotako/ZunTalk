package orchestrator

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/takoikatakotako/ZunTalk/agent/model"
	"google.golang.org/genai"
)

const plannerSystemPrompt = `あなたはずんだもんの「司令塔」エージェントなのだ。
ユーザーの発話を読み、必要な情報源（ツール）を選んで実行計画を立てる。

利用できるツール:
- calendar: カレンダーの予定を調べる（端末の標準カレンダー）
- gmail: Gmailのメールを調べる

ルール:
- 予定にもメールにも関係しない雑談だけのときは steps を空配列にする。
- 各ステップの query には、そのツールで具体的に何を調べるべきかを日本語で書く。
- 必要なツールだけを選ぶ。両方必要なら両方入れてよい。`

// planSchema は planner の出力（steps 配列）を強制する JSON スキーマ。
func planSchema() *genai.Schema {
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
							Enum: []string{string(model.CapabilityCalendar), string(model.CapabilityGmail)},
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
func (o *Orchestrator) Plan(ctx context.Context, userInput string) ([]model.PlanStep, error) {
	raw, err := o.llm.GenerateJSON(ctx, plannerSystemPrompt, userInput, planSchema())
	if err != nil {
		return nil, err
	}

	var out struct {
		Steps []model.PlanStep `json:"steps"`
	}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return nil, fmt.Errorf("計画のパースに失敗: %w (raw=%s)", err, raw)
	}

	// 未知の capability は念のため除外する。
	steps := make([]model.PlanStep, 0, len(out.Steps))
	for _, s := range out.Steps {
		switch s.Capability {
		case model.CapabilityCalendar, model.CapabilityGmail:
			steps = append(steps, s)
		}
	}
	return steps, nil
}
