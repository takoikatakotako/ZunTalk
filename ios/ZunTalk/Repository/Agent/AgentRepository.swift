import Foundation

/// エージェントとのステートレスな往復を駆動する。
///
/// 1. POST /agent {message} → plan（tool_calls）or final
/// 2. plan があれば端末でツール実行（Gmail/Calendar を自分のトークンで叩く）
/// 3. POST /agent {message, results} → final（ずんだもんの返答）
final class AgentRepository {
    private let executor: AgentToolExecuting

    init(executor: AgentToolExecuting = ToolExecutor()) {
        self.executor = executor
    }

    /// 1回の発話に対する往復を実行し、最終結果（返答＋計画＋実行結果）を返す。
    func run(message: String) async throws -> AgentRunResult {
        // 1巡目: 計画を取得
        let first = try await post(AgentRequest(message: message, results: nil))

        // ツール不要（雑談など）→ そのまま返答
        if first.type == AgentResponseType.final {
            return AgentRunResult(reply: first.reply ?? "", emotion: first.emotion, plan: [], results: [])
        }

        let plan = first.plan ?? []

        // 端末で各ツールを実行
        var results: [AgentStepResult] = []
        for step in plan {
            let result = await executor.execute(capability: step.capability, query: step.query)
            results.append(result)
        }

        // 2巡目: 結果を渡して最終応答を取得
        let second = try await post(AgentRequest(message: message, results: results))
        return AgentRunResult(reply: second.reply ?? "", emotion: second.emotion, plan: plan, results: results)
    }

    private func post(_ body: AgentRequest) async throws -> AgentResponse {
        guard let url = URL(string: AgentConfig.agentEndpoint) else {
            throw AgentError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let apiKey = AgentConfig.apiKey
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw AgentError.api(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(AgentResponse.self, from: data)
    }
}

/// 往復1回の結果。
struct AgentRunResult {
    let reply: String
    /// サーバーが返した感情（neutral/happy/... 。未指定なら nil）。
    let emotion: String?
    let plan: [AgentPlanStep]
    let results: [AgentStepResult]
}

enum AgentError: Error, LocalizedError {
    case invalidURL
    case api(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "エージェントの URL が不正なのだ"
        case .api(let code, let body):
            return "エージェントAPIエラー(\(code)): \(body)"
        }
    }
}
