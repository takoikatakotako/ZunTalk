import Foundation
import Testing
@testable import ZunTalk

@MainActor
struct ChatViewModelTests {

    // MARK: - Helper

    /// 条件が満たされるまでポーリングして待つ（CI環境でも安定動作）
    private func waitUntil(
        timeout: Duration = .seconds(10),
        _ condition: @escaping () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else {
                throw WaitError.timeout
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func makeViewModel(
        response: String = "モックレスポンスなのだ",
        shouldThrow: Bool = false,
        delay: Duration? = nil
    ) -> (ChatViewModel, MockTextGenerationRepository) {
        let mockRepo = MockTextGenerationRepository()
        mockRepo.response = response
        mockRepo.shouldThrow = shouldThrow
        mockRepo.delay = delay

        let viewModel = ChatViewModel(
            textGenerationRepository: mockRepo,
            voicevoxRepository: MockTextToSpeechRepository()
        )
        return (viewModel, mockRepo)
    }

    // MARK: - 初期化

    @Test func testInitialState() async throws {
        let (viewModel, _) = makeViewModel()

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.inputText == "")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isPlayingVoice == false)
        #expect(viewModel.playingMessageId == nil)
        #expect(viewModel.isConversationEnded == false)
    }

    // MARK: - 初回挨拶

    @Test func testOnAppearGeneratesInitialGreeting() async throws {
        let (viewModel, _) = makeViewModel(response: "やっほー！ずんだもんなのだ！")

        viewModel.onAppear()
        try await waitUntil { viewModel.isLoading == false && viewModel.messages.count == 1 }

        #expect(viewModel.messages.first?.role == .assistant)
        #expect(viewModel.messages.first?.content == "やっほー！ずんだもんなのだ！")
    }

    @Test func testOnAppearCalledTwiceDoesNotDuplicate() async throws {
        let (viewModel, _) = makeViewModel(response: "こんにちはなのだ！")

        viewModel.onAppear()
        try await waitUntil { viewModel.isLoading == false && viewModel.messages.count == 1 }

        viewModel.onAppear()
        try await Task.sleep(for: .milliseconds(200))

        #expect(viewModel.messages.count == 1)
    }

    // MARK: - メッセージ送信

    @Test func testSendMessage() async throws {
        let (viewModel, _) = makeViewModel(response: "元気なのだ！")

        viewModel.inputText = "こんにちは"
        viewModel.sendMessage()
        try await waitUntil { viewModel.isLoading == false && viewModel.messages.count == 2 }

        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages[0].content == "こんにちは")
        #expect(viewModel.messages[1].role == .assistant)
        #expect(viewModel.messages[1].content == "元気なのだ！")
    }

    @Test func testSendMessageClearsInputText() async throws {
        let (viewModel, _) = makeViewModel()

        viewModel.inputText = "テスト"
        viewModel.sendMessage()

        #expect(viewModel.inputText == "")
    }

    @Test func testSendEmptyMessageDoesNothing() async throws {
        let (viewModel, _) = makeViewModel()

        viewModel.inputText = "   "
        viewModel.sendMessage()

        #expect(viewModel.messages.isEmpty)
    }

    @Test func testSendMessageWhileLoadingDoesNothing() async throws {
        let (viewModel, _) = makeViewModel(delay: .seconds(1))

        viewModel.inputText = "最初のメッセージ"
        viewModel.sendMessage()

        // ローディング中に2つ目を送信
        viewModel.inputText = "2つ目のメッセージ"
        viewModel.sendMessage()

        try await waitUntil { viewModel.isLoading == false }

        let userMessages = viewModel.messages.filter { $0.role == .user }
        #expect(userMessages.count == 1)
    }

    // MARK: - エラーハンドリング

    @Test func testSendMessageWithErrorShowsErrorMessage() async throws {
        let (viewModel, _) = makeViewModel(shouldThrow: true)

        viewModel.inputText = "テスト"
        viewModel.sendMessage()
        try await waitUntil { viewModel.isLoading == false && viewModel.messages.count == 2 }

        #expect(viewModel.messages[1].role == .assistant)
        #expect(viewModel.messages[1].content.contains("ごめんなさい"))
    }

    // MARK: - 会話回数制限

    @Test func testConversationEndsAfterMaxRoundTrips() async throws {
        let (viewModel, _) = makeViewModel(response: "返答なのだ")

        for i in 1...40 {
            try await waitUntil { viewModel.isLoading == false }
            viewModel.inputText = "メッセージ\(i)"
            viewModel.sendMessage()
        }
        try await waitUntil { viewModel.isLoading == false }

        #expect(viewModel.isConversationEnded == true)
    }

    @Test func testCannotSendMessageAfterConversationEnded() async throws {
        let (viewModel, _) = makeViewModel()

        for i in 1...40 {
            try await waitUntil { viewModel.isLoading == false }
            viewModel.inputText = "メッセージ\(i)"
            viewModel.sendMessage()
        }
        try await waitUntil { viewModel.isLoading == false }

        let messageCountBefore = viewModel.messages.count

        viewModel.inputText = "もう1つ"
        viewModel.sendMessage()
        try await Task.sleep(for: .milliseconds(200))

        #expect(viewModel.messages.count == messageCountBefore)
    }

    // MARK: - 会話履歴

    @Test func testConversationHistoryPassedToRepository() async throws {
        let (viewModel, mockRepo) = makeViewModel(response: "返答なのだ")

        viewModel.inputText = "1つ目"
        viewModel.sendMessage()
        try await waitUntil { viewModel.isLoading == false && viewModel.messages.count == 2 }

        viewModel.inputText = "2つ目"
        viewModel.sendMessage()
        try await waitUntil { viewModel.isLoading == false && viewModel.messages.count == 4 }

        let lastInputs = mockRepo.lastInputs
        #expect(lastInputs != nil)

        let roles = lastInputs!.map { $0.role }
        #expect(roles.first == ChatMessage.Role.system.rawValue)
        #expect(roles.contains(ChatMessage.Role.user.rawValue))
        #expect(roles.contains(ChatMessage.Role.assistant.rawValue))
    }
}

// MARK: - Mock Repositories

private class MockTextGenerationRepository: TextGenerationRepository {
    var response = "モックレスポンスなのだ"
    var shouldThrow = false
    var delay: Duration?
    var lastInputs: [ChatMessage]?

    func generateResponse(inputs: [ChatMessage]) async throws -> String {
        lastInputs = inputs
        if let delay {
            try await Task.sleep(for: delay)
        }
        if shouldThrow {
            throw MockError.testError
        }
        return response
    }
}

private class MockTextToSpeechRepository: TextToSpeechRepository {
    func installVoicevox() async throws {}
    func setupSynthesizer() throws {}
    func synthesize(text: String) async throws -> Data { Data() }
    func cleanupSynthesizer() {}
}

private enum MockError: Error {
    case testError
}

private enum WaitError: Error {
    case timeout
}
