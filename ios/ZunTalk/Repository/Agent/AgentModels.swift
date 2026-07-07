import Foundation

// MARK: - Agent API Models（Go サーバー agent/model/agent.go と対応）

/// 端末が実行するツールの種類。
enum AgentCapability: String {
    case calendar
    case gmail
}

/// /agent へのリクエスト。
/// - 1巡目: message のみ → サーバーは plan を返す
/// - 2巡目: message ＋ results（端末の実行結果）→ サーバーは reply を返す
struct AgentRequest: Codable {
    let message: String
    /// 端末で実行できるツール。nil/空ならサーバー側で後方互換として全ツール扱い。
    let capabilities: [String]?
    /// 利用回数制限用の端末ID。
    let deviceId: String?
    /// 端末でのツール実行結果（2巡目のみ。nil なら JSON から省略される）。
    let results: [AgentStepResult]?
}

/// planner が立てた「端末に実行してほしいツール」1件。
struct AgentPlanStep: Codable {
    let capability: String
    let query: String
    let reason: String?
}

/// 端末がツールを実行した結果（端末→サーバー）。
struct AgentStepResult: Codable {
    let capability: String
    let query: String?
    let content: String
    let error: String?
}

/// /agent のレスポンス（type による判別）。
struct AgentResponse: Codable {
    /// "tool_calls"（端末にツール実行を依頼）または "final"（最終応答）。
    let type: String
    let plan: [AgentPlanStep]?
    let reply: String?
    /// 返答に対応する感情（表情用）。neutral/happy/sad/surprised/troubled。
    let emotion: String?
}

enum AgentResponseType {
    static let toolCalls = "tool_calls"
    static let final = "final"
}
