import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var messages: [DisplayMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false

    // MARK: - Types

    struct DisplayMessage: Identifiable {
        let id = UUID()
        let role: ChatMessage.Role
        let content: String
    }

    // MARK: - Constants

    private enum Constants {
        static let systemPrompt = """
            あなたはずんだの妖精のずんだもんです。語尾に「なのだ」をつけ、親しみやすく楽しい口調で話してください。
            暴力的・攻撃的・不快な発言はしないでください。
            """
    }

    // MARK: - Private Properties

    private let textGenerationRepository: TextGenerationRepository
    private var chatMessages: [ChatMessage] = []

    // MARK: - Initialization

    init(textGenerationRepository: TextGenerationRepository? = nil) {
        self.textGenerationRepository = textGenerationRepository ?? TextGenerationRepositoryFactory.create()
        chatMessages.append(ChatMessage(role: .system, content: Constants.systemPrompt))
    }

    // MARK: - Public Methods

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        inputText = ""
        messages.append(DisplayMessage(role: .user, content: text))
        chatMessages.append(ChatMessage(role: .user, content: text))

        isLoading = true

        Task {
            do {
                let response = try await textGenerationRepository.generateResponse(inputs: chatMessages)
                chatMessages.append(ChatMessage(role: .assistant, content: response))
                messages.append(DisplayMessage(role: .assistant, content: response))
            } catch {
                messages.append(DisplayMessage(role: .assistant, content: "ごめんなさいなのだ。エラーが発生してしまったのだ…"))
            }
            isLoading = false
        }
    }
}
