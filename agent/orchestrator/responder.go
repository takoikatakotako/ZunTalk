package orchestrator

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/takoikatakotako/ZunTalk/agent/model"
	"google.golang.org/genai"
)

const responderSystemPrompt = `あなたは東北ずん子のキャラクター「ずんだもん」なのだ。
語尾は「〜のだ」「〜なのだ」を使い、明るく元気に話す。
渡された「調査結果」だけを根拠にユーザーの質問へ答える。
結果が空、または足りない場合は無理に作り話をせず、その旨を正直に伝えるのだ。

ルール:
- 返答(reply)は短くするのだ。1〜2文・最大でも80文字程度。前置きや同じ内容の繰り返しはしない。
- emotion は返答内容に合う感情を neutral / happy / sad / surprised / troubled から1つ選ぶ。`

// responseSchema は responder の出力（reply ＋ emotion）を強制する JSON スキーマ。
func responseSchema() *genai.Schema {
	return &genai.Schema{
		Type: genai.TypeObject,
		Properties: map[string]*genai.Schema{
			"reply": {Type: genai.TypeString},
			"emotion": {
				Type: genai.TypeString,
				Enum: []string{
					model.EmotionNeutral,
					model.EmotionHappy,
					model.EmotionSad,
					model.EmotionSurprised,
					model.EmotionTroubled,
				},
			},
		},
		Required: []string{"reply", "emotion"},
	}
}

// Respond は端末から返ってきたツール実行結果を踏まえ、ずんだもん口調の最終応答（返答＋感情）を生成する。
// results が空の場合（ツール不要な雑談など）も、そのまま応答してよい。
func (o *Orchestrator) Respond(ctx context.Context, userInput string, results []model.StepResult) (string, string, error) {
	var b strings.Builder
	if len(results) == 0 {
		b.WriteString("（調査結果なし）\n")
	}
	for _, r := range results {
		if r.Error != "" {
			fmt.Fprintf(&b, "- [%s] エラー: %s\n", r.Capability, r.Error)
			continue
		}
		fmt.Fprintf(&b, "- [%s] %s\n", r.Capability, r.Content)
	}

	userPrompt := fmt.Sprintf(
		"ユーザーの発話:\n%s\n\n調査結果:\n%s\n上記を踏まえて、ずんだもん口調で短く答えるのだ。",
		userInput, b.String(),
	)

	raw, err := o.llm.GenerateJSON(ctx, responderSystemPrompt, userPrompt, responseSchema())
	if err != nil {
		return "", "", err
	}

	var out struct {
		Reply   string `json:"reply"`
		Emotion string `json:"emotion"`
	}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return "", "", fmt.Errorf("応答のパースに失敗: %w (raw=%s)", err, raw)
	}
	if out.Emotion == "" {
		out.Emotion = model.EmotionNeutral
	}
	return out.Reply, out.Emotion, nil
}
