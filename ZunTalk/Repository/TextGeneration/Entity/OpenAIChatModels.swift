import Foundation

// MARK: - Request/Response Models

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let max_tokens: Int
    let temperature: Double
}

struct OpenAIChatResponse: Codable {
    let id: String
    let choices: [ChatChoice]
}

struct ChatChoice: Codable {
    let message: ChatMessage?
    let finish_reason: String?
}