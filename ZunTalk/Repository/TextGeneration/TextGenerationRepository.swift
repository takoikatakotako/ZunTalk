import Foundation

protocol TextGenerationRepository {
//    func generateResponse(userMessage: String) async throws -> String
    func generateResponse(inputs: [ChatMessage]) async throws -> String
}
