import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AIModelType: String, CaseIterable {
    case freeServer = "free_server"
    case foundationModels = "foundation_models"

    var displayName: String {
        switch self {
        case .freeServer:
            return "無料サーバー（広告付き）"
        case .foundationModels:
            return "Foundation Models（オンデバイス）"
        }
    }

    var description: String {
        switch self {
        case .freeServer:
            return "広告が表示されますが、無料でご利用いただけます"
        case .foundationModels:
            return "iOS 26+で利用可能。完全無料でプライバシー重視のオンデバイスAI"
        }
    }

    var iconName: String {
        switch self {
        case .freeServer:
            return "server.rack"
        case .foundationModels:
            return "cpu"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .foundationModels:
            if #available(iOS 26.0, *) {
                #if canImport(FoundationModels)
                let model = SystemLanguageModel.default
                switch model.availability {
                case .available:
                    return true
                case .unavailable:
                    return false
                }
                #else
                return false
                #endif
            }
            return false
        default:
            return true
        }
    }
}
