import Foundation

enum AIModelType: String, CaseIterable {
    case freeServer = "free_server"
    case openAI = "openai"
    case foundationModels = "foundation_models"

    var displayName: String {
        switch self {
        case .freeServer:
            return "無料サーバー（広告付き）"
        case .openAI:
            return "OpenAI"
        case .foundationModels:
            return "Foundation Models（オンデバイス）"
        }
    }

    var description: String {
        switch self {
        case .freeServer:
            return "広告が表示されますが、無料でご利用いただけます"
        case .openAI:
            return "OpenAI APIキーが必要です。料金は従量課金制です"
        case .foundationModels:
            return "iOS 26+で利用可能。完全無料でプライバシー重視のオンデバイスAI"
        }
    }

    var iconName: String {
        switch self {
        case .freeServer:
            return "server.rack"
        case .openAI:
            return "brain.head.profile"
        case .foundationModels:
            return "cpu"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .foundationModels:
            if #available(iOS 26.0, *) {
                return true
            }
            return false
        default:
            return true
        }
    }
}
