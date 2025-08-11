import Foundation

protocol TextGenerationRepository {
    func generateResponse(userMessage: String) async throws -> String
    func generateResponse(messages: [ChatMessage]) async throws -> String
}