import Foundation

enum FoundationModelsTextGenerationError: Error, LocalizedError {
    case modelUnavailable(String)
    case sessionCreationFailed
    case generationFailed(Error)
    case unavailableOS
    case noResponse
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return "Foundation Modelsが利用できません: \(reason)"
        case .sessionCreationFailed:
            return "AIセッションの作成に失敗しました"
        case .generationFailed(let error):
            return "テキスト生成に失敗しました: \(error.localizedDescription)"
        case .unavailableOS:
            return "Foundation ModelsはiOS 26以上が必要です"
        case .noResponse:
            return "AIからレスポンスが得られませんでした"
        case .invalidInput:
            return "入力が無効です"
        }
    }
}
