// Package orchestrator はずんだもんエージェントの司令塔。
//
// サーバー側は AI のオーケストレーション（planner と responder）のみを担う。
// カレンダーの実際の読み取りは端末(iOS)が EventKit で行うため、
// ここには実行ワーカー（ツールの API クライアント）は存在しない。
package orchestrator

import "github.com/takoikatakotako/ZunTalk/agent/llm"

// Orchestrator は planner / responder をまとめる。
type Orchestrator struct {
	llm *llm.Gemini
}

// New は Orchestrator を生成する。
func New(gemini *llm.Gemini) *Orchestrator {
	return &Orchestrator{llm: gemini}
}
