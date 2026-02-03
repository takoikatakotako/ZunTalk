import Foundation
import FoundationModels

@available(iOS 26.0, *)
class FoundationModelsTextGenerationRepository: TextGenerationRepository {

    private var session: LanguageModelSession?
    private var currentSystemPrompt: String?
    private let model: SystemLanguageModel

    init() {
        self.model = SystemLanguageModel.default
        self.session = nil
        self.currentSystemPrompt = nil
    }

    func generateResponse(inputs: [ChatMessage]) async throws -> String {
        // Check model availability
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw FoundationModelsTextGenerationError.modelUnavailable(String(describing: reason))
        }

        // Convert ChatMessage array to prompt format
        let prompt = buildPrompt(from: inputs)

        // Create or reuse session (recreate if system prompt changed)
        let systemPrompt = extractSystemPrompt(from: inputs)
        if session == nil || currentSystemPrompt != systemPrompt {
            session = LanguageModelSession {
                systemPrompt
            }
            currentSystemPrompt = systemPrompt
        }

        guard let session = session else {
            throw FoundationModelsTextGenerationError.sessionCreationFailed
        }

        do {
            // Generate response with appropriate options for Zundamon character
            let options = GenerationOptions(
                sampling: .random(probabilityThreshold: 0.9, seed: nil),
                temperature: 0.8,
                maximumResponseTokens: 500
            )

            let response = try await session.respond(
                to: prompt,
                options: options
            )

            // 前後の空白・改行を削除
            let trimmedContent = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedContent.isEmpty else {
                throw FoundationModelsTextGenerationError.noResponse
            }

            return trimmedContent

        } catch let error as FoundationModelsTextGenerationError {
            // 既にFoundationModelsTextGenerationErrorの場合はそのまま再スロー
            throw error
        } catch {
            // その他のエラーはラップ
            throw FoundationModelsTextGenerationError.generationFailed(error)
        }
    }

    // MARK: - Private Helpers

    private func extractSystemPrompt(from messages: [ChatMessage]) -> String {
        return messages.first(where: { $0.role == ChatMessage.Role.system.rawValue })?.content
            ?? "あなたはずんだもんです。"
    }

    private func buildPrompt(from messages: [ChatMessage]) -> String {
        var promptParts: [String] = []

        for message in messages where message.role != ChatMessage.Role.system.rawValue {
            let prefix = message.role == ChatMessage.Role.user.rawValue ? "User" : "Assistant"
            promptParts.append("\(prefix): \(message.content)")
        }

        // システムメッセージのみの場合、または最後がユーザーメッセージの場合は
        // Assistantの応答を促すために"Assistant:"を追加
        let nonSystemMessages = messages.filter { $0.role != ChatMessage.Role.system.rawValue }
        if nonSystemMessages.isEmpty || nonSystemMessages.last?.role == ChatMessage.Role.user.rawValue {
            promptParts.append("Assistant:")
        }

        return promptParts.joined(separator: "\n")
    }

    deinit {
        session = nil
    }
}
