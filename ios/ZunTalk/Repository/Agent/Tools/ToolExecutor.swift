import Foundation

/// plan の各ステップを端末側で実行するもの。
protocol AgentToolExecuting {
    func execute(capability: String, query: String) async -> AgentStepResult
}

/// Google のアクセストークンを使って Gmail / Calendar を端末から実行する。
/// トークンは GoogleAuthManager（端末内）から取得し、サーバーには渡さない。
final class ToolExecutor: AgentToolExecuting {
    func execute(capability: String, query: String) async -> AgentStepResult {
        do {
            let token = try await GoogleAuthManager.shared.accessToken()

            let content: String
            switch AgentCapability(rawValue: capability) {
            case .calendar:
                content = try await CalendarTool.fetch(accessToken: token, query: query)
            case .gmail:
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
