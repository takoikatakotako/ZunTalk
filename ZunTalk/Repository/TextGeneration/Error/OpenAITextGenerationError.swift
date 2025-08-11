import Foundation

enum OpenAITextGenerationError: Error, LocalizedError {
    case invalidAPIKey
    case encodingError
    case decodingError
    case apiError(Int)
    case networkError(Error)
    case noResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "OpenAI API キーが無効です"
        case .encodingError:
            return "リクエストのエンコードに失敗しました"
        case .decodingError:
            return "レスポンスのデコードに失敗しました"
        case .apiError(let statusCode):
            return "OpenAI API エラー (ステータスコード: \(statusCode))"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .noResponse:
            return "OpenAI APIからレスポンスが得られませんでした"
        }
    }
}