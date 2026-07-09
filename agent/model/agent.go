package model

// Capability はエージェントが扱える能力（=端末側のどのツールを実行させるか）を表す。
type Capability string

const (
	CapabilityCalendar Capability = "calendar"
)

// AgentRequest は /agent エンドポイントへのリクエスト。
//
// ステートレス設計: 端末(iOS)が会話を駆動する。
//   - 1巡目: Message のみ送る → サーバーは計画(Plan)を返す
//   - 端末は Plan の各ステップを実行（カレンダーは EventKit で端末内から読む）
//   - 2巡目: Message ＋ Results（端末での実行結果）を送る → サーバーは最終応答(Reply)を返す
type AgentRequest struct {
	// Message はユーザーの発話（例: 「今日の予定を教えて」）。
	Message string `json:"message"`
	// Results は端末がツールを実行した結果（2巡目以降のみ）。空なら計画フェーズ。
	Results []StepResult `json:"results,omitempty"`
	// Capabilities は端末が実行できるツールの申告（例: 本番ビルドは calendar のみ）。
	// 空・欠落なら全ツール利用可能とみなす（後方互換）。
	Capabilities []Capability `json:"capabilities,omitempty"`
	// DeviceID は利用回数制限のための端末識別子（Keychain の UUID）。
	// 空でも動くが、制限の対象外にはならず匿名バケットで数えられる。
	DeviceID string `json:"deviceId,omitempty"`
}

// PlanStep は planner が立てた「端末に実行してほしいツール呼び出し」1件。
type PlanStep struct {
	// Capability はこのステップで端末が叩くべきツール。
	Capability Capability `json:"capability"`
	// Query はそのツールで何を調べるべきかの具体的な指示（日本語）。
	Query string `json:"query"`
	// Reason はなぜこのステップが必要かの理由（デモ可視化用）。
	Reason string `json:"reason,omitempty"`
}

// StepResult は端末がツールを実行した結果（端末→サーバー）。
type StepResult struct {
	Capability Capability `json:"capability"`
	// Query は対応する PlanStep の Query（任意。文脈付与用）。
	Query string `json:"query,omitempty"`
	// Content は端末が取得した結果テキスト/JSON。
	Content string `json:"content"`
	// Error は端末側で実行に失敗した場合のエラー内容。
	Error string `json:"error,omitempty"`
}

// AgentResponse は /agent エンドポイントのレスポンス（Type による判別共用体）。
type AgentResponse struct {
	// Type は "tool_calls"（端末にツール実行を依頼）または "final"（最終応答）。
	Type string `json:"type"`
	// Plan は Type=="tool_calls" のとき、端末に実行してほしいツール一覧。
	Plan []PlanStep `json:"plan,omitempty"`
	// Reply は Type=="final" のとき、ずんだもんの最終応答テキスト。
	Reply string `json:"reply,omitempty"`
	// Emotion は Type=="final" のとき、返答に対応する感情（端末の表情切替用）。
	Emotion string `json:"emotion,omitempty"`
}

const (
	ResponseTypeToolCalls = "tool_calls"
	ResponseTypeFinal     = "final"
)

// 返答の感情（表情にマップする）。
const (
	EmotionNeutral   = "neutral"
	EmotionHappy     = "happy"
	EmotionSad       = "sad"
	EmotionSurprised = "surprised"
	EmotionTroubled  = "troubled"
)

// ErrorResponse はエラー時のレスポンス（backend と同じ形式に揃える）。
type ErrorResponse struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}
