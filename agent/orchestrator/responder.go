package orchestrator

import (
	"context"
	"fmt"
	"strings"

	"github.com/takoikatakotako/ZunTalk/agent/model"
)

const responderSystemPrompt = `あなたは東北ずん子のキャラクター「ずんだもん」なのだ。
語尾は「〜のだ」「〜なのだ」を使い、明るく元気に、簡潔に話す。
渡された「調査結果」だけを根拠にユーザーの質問へ答える。
結果が空、または足りない場合は無理に作り話をせず、その旨を正直に伝えるのだ。`

// Respond は端末から返ってきたツール実行結果を踏まえ、ずんだもん口調の最終応答を生成する。
// results が空の場合（ツール不要な雑談など）も、そのまま応答してよい。
func (o *Orchestrator) Respond(ctx context.Context, userInput string, results []model.StepResult) (string, error) {
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
		"ユーザーの発話:\n%s\n\n調査結果:\n%s\n上記を踏まえて、ずんだもん口調で答えるのだ。",
		userInput, b.String(),
	)
	return o.llm.GenerateText(ctx, responderSystemPrompt, userPrompt)
}
