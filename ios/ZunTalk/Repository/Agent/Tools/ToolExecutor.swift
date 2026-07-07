import Foundation

/// plan の各ステップを端末側で実行するもの。
protocol AgentToolExecuting {
    func execute(capability: String, query: String) async -> AgentStepResult
}

/// plan の各ステップを端末側のツールで実行する。
/// - calendar: EventKit（端末内カレンダー DB）。Google 連携・トークン不要
/// - gmail: Gmail API。トークンは GoogleAuthManager（端末内）から取得し、サーバーには渡さない
final class ToolExecutor: AgentToolExecuting {
    func execute(capability: String, query: String) async -> AgentStepResult {
        do {
            let content: String
            switch AgentCapability(rawValue: capability) {
            case .calendar:
                content = try await CalendarTool.fetch(query: query)
            case .gmail:
                let token = try await GoogleAuthManager.shared.accessToken()
                content = try await GmailTool.fetch(accessToken: token, query: query)
            case .none:
                return AgentStepResult(capability: capability, query: query, content: "",
                                       error: "未知のツール: \(capability)")
            }
            return AgentStepResult(capability: capability, query: query, content: content, error: nil)
        } catch {
            return AgentStepResult(capability: capability, query: query, content: "",
                                   error: error.localizedDescription)
        }
    }
}

enum AgentToolError: Error, LocalizedError {
    case api(String, Int)

    var errorDescription: String? {
        switch self {
        case .api(let name, let code):
            return "\(name) APIエラー(\(code))"
        }
    }
}
