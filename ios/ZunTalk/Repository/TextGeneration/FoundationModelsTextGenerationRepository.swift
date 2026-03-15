import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
class FoundationModelsTextGenerationRepository: TextGenerationRepository {

    private var session: LanguageModelSession?
    private var currentSystemPrompt: String?
    private let model: SystemLanguageModel

    private static let defaultInstructions = "あなたは親しみやすいAIアシスタントです。日本語で短く簡潔に返答してください。"
    private static let endConversationInstructions = "あなたは親しみやすいAIアシスタントです。日本語で短く簡潔に返答してください。ユーザーとの会話を終了する挨拶をしてください。"

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

        // Use simplified instructions for on-device model
        let systemMessages = inputs.filter { $0.role == ChatMessage.Role.system.rawValue }
        let isEndConversation = systemMessages.count > 1
        let instructions = isEndConversation ? Self.endConversationInstructions : Self.defaultInstructions

        // Recreate session if instructions changed
        if session == nil || currentSystemPrompt != instructions {
            session = LanguageModelSession(instructions: instructions)
            currentSystemPrompt = instructions
        }

        // session is guaranteed to be non-nil after the block above
        let activeSession = session!

        // Determine the message to send to the session
        let latestMessage: String
        if let userMessage = inputs.last(where: { $0.role == ChatMessage.Role.user.rawValue })?.content {
            latestMessage = userMessage
        } else if systemMessages.count > 1 {
            // End conversation: no new user message, but new system instruction was added
            // Send a natural user message to trigger farewell
            latestMessage = "そろそろ時間だね、バイバイ！"
        } else {
            // Initial greeting (system prompt only)
            latestMessage = "もしもし！"
        }

        do {
            let options = GenerationOptions(
                sampling: .random(probabilityThreshold: 0.9, seed: nil),
                maximumResponseTokens: 500
            )

            let response = try await activeSession.respond(
                to: latestMessage,
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

    deinit {
        session = nil
    }
}
#endif
