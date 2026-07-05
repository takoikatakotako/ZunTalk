import Foundation

/// エージェント（Cloud Run）への接続設定。xcconfig → Info.plist 経由で読み込む。
enum AgentConfig {
    /// エージェントの Base URL（AGENT_BASE_URL）。
    static var baseURL: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "AGENT_BASE_URL") as? String,
              !value.isEmpty else {
            fatalError("AGENT_BASE_URL not found in Info Dictionary")
        }
        return value
    }

    /// Cloud Run を保護する共有 APIキー（AGENT_API_KEY）。未設定なら空。
    static var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "AGENT_API_KEY") as? String ?? ""
    }

    /// エージェントのエンドポイント。
    static var agentEndpoint: String {
        "\(baseURL)/agent"
    }
}
