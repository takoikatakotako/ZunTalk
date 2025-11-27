import Foundation

enum AIModelType: String, CaseIterable {
    case freeServer = "free_server"
    case openAI = "openai"

    var displayName: String {
        switch self {
        case .freeServer:
            return "無料サーバー（広告付き）"
        case .openAI:
            return "OpenAI"
        }
    }

    var description: String {
        switch self {
        case .freeServer:
            return "広告が表示されますが、無料でご利用いただけます"
        case .openAI:
            return "OpenAI APIキーが必要です。料金は従量課金制です"
        }
    }

    var iconName: String {
        switch self {
        case .freeServer:
            return "server.rack"
        case .openAI:
            return "brain.head.profile"
        }
    }
}
