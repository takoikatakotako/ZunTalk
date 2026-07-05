// Package orchestrator はずんだもんエージェントの司令塔。
//
// サーバー側は AI のオーケストレーション（planner と responder）のみを担う。
// Gmail/Calendar の実際のAPI呼び出しは端末(iOS)が自分のトークンで行うため、
// ここには実行ワーカー（gmail/calendar の API クライアント）は存在しない。
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
