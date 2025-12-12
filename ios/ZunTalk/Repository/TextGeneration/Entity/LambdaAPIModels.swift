import Foundation

// MARK: - Lambda API Models

/// Lambda API Chat Request
struct LambdaChatRequest: Codable {
    let messages: [ChatMessage]
    let model: String?
    let maxTokens: Int?
}

/// Lambda API Chat Response
struct LambdaChatResponse: Codable {
    let message: ChatMessage
    let tokensUsed: Int
}

/// Lambda API Error Response
struct LambdaErrorResponse: Codable {
    let code: String
    let message: String
}
