import Foundation
import Testing
@testable import ZunTalk

@MainActor
struct ChatViewModelTests {

    // MARK: - 初期化

    @Test func testInitialState() async throws {
        let viewModel = ChatViewModel(
            textGenerationRepository: MockTextGenerationRepository(),
            voicevoxRepository: MockTextToSpeechRepository()
        )

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.inputText == "")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isPlayingVoice == false)
        #expect(viewModel.playingMessageId == nil)
        #expect(viewModel.isConversationEnded == false)
    }

    // MARK: - 初回挨拶

    @Test func testOnAppearGeneratesInitialGreeting() async throws {
        let mockRepo = MockTextGenerationRepository()
        mockRepo.response = "やっほー！ずんだもんなのだ！"

        let viewModel = ChatViewModel(
            textGenerationRepository: mockRepo,
            voicevoxRepository: MockTextToSpeechRepository()
        )

        viewModel.onAppear()

        // 非同期処理の完了を待つ
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.role == .assistant)
        #expect(viewModel.messages.first?.content == "やっほー！ずんだもんなのだ！")
        #expect(viewModel.isLoading == false)
    }

    @Test func testOnAppearCalledTwiceDoesNotDuplicate() async throws {
        let mockRepo = MockTextGenerationRepository()
        mockRepo.response = "こんにちはなのだ！"

        let viewModel = ChatViewModel(
            textGenerationRepository: mockRepo,
            voicevoxRepository: MockTextToSpeechRepository()
        )

        viewModel.onAppear()
        try await Task.sleep(for: .milliseconds(100))

        viewModel.onAppear()
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.messages.count == 1)
    }

    // MARK: - メッセージ送信

    @Test func testSendMessage() async throws {
        let mockRepo = MockTextGenerationRepository()
        mockRepo.response = "元気なのだ！"

        let viewModel = ChatViewModel(
            textGenerationRepository: mockRepo,
            voicevoxRepository: MockTextToSpeechRepository()
        )

        viewModel.inputText = "こんにちは"
        viewModel.sendMessage()

        try await Task.sleep(for: .milliseconds(100))

        // ユーザーメッセージ + ずんだもんの返答
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages[0].content == "こんにちは")
        #expect(viewModel.messages[1].role == .assistant)
        #expect(viewModel.messages[1].content == "元気なのだ！")
    }

    @Test func testSendMessageClearsInputText() async throws {
        let viewModel = ChatViewModel(
            textGenerationRepository: MockTextGenerationRepository(),
            voicevoxRepository: MockTextToSpeechRepository()
        )

        viewModel.inputText = "テスト"
        viewModel.sendMessage()

        #expect(viewModel.inputText == "")
    }

    @Test func testSendEmptyMessageDoesNothing() async throws {
        let viewModel = ChatViewModel(
            textGenerationRepository: MockTextGenerationRepository(),
            voicevoxRepository: MockTextToSpeechRepository()
        )

        viewModel.inputText = "   "
        viewModel.sendMessage()

        #expect(viewModel.messages.isEmpty)
    }

    @Test func testSendMessageWhileLoadingDoesNothing() async throws {
        let slowRepo = MockTextGenerationRepository()
        slowRepo.delay = .milliseconds(500)

        let viewModel = ChatViewModel(
            textGenerationRepository: slowRepo,
            voicevoxRepository: MockTextToSpeechRepository()
        )

        viewModel.inputText = "最初のメッセージ"
        viewModel.sendMessage()

        // ローディング中に2つ目を送信
        viewModel.inputText = "2つ目のメッセージ"
        viewModel.sendMessage()

        try await Task.sleep(for: .milliseconds(600))

        // ユーザーメッセージは1つだけ
        let userMessages = viewModel.messages.filter { $0.role == .user }
        #expect(userMessages.count == 1)
    }

    // MARK: - エラーハンドリング

    @Test func testSendMessageWithErrorShowsErrorMessage() async throws {
        let mockRepo = MockTextGenerationRepository()
        mockRepo.shouldThrow = true

        let viewModel = ChatViewModel(
            textGenerationRepository: mockRepo,
            voicevoxRepository: MockTextToSpeechRepository()
        )

        viewModel.inputText = "テスト"
        viewModel.sendMessage()

        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[1].role == .assistant)
        #expect(viewModel.messages[1].content.contains("ごめんなさい"))
        #expect(viewModel.isLoading == false)
    }

    // MARK: - 会話回数制限

    @Test func testConversationEndsAfterMaxRoundTrips() async throws {
        let mockRepo = MockTextGenerationRepository()
        mockRepo.response = "返答なのだ"

        let viewModel = ChatViewModel(
            textGenerationRepository: mockRepo,
            voicevoxRepository: MockTextToSpeechRepository()
        )

        // 40回メッセージを送信
        for i in 1...40 {
            viewModel.inputText = "メッセージ\(i)"
            viewModel.sendMessage()
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(viewModel.isConversationEnded == true)
    }

    @Test func testCannotSendMessageAfterConversationEnded() async throws {
        let mockRepo = MockTextGenerationRepository()
        let viewModel = ChatViewModel(
            textGenerationRepository: mockRepo,
            voicevoxRepository: MockTextToSpeechRepository()
        )

        // 40回送信して会話終了
        for i in 1...40 {
            viewModel.inputText = "メッセージ\(i)"
            viewModel.sendMessage()
            try await Task.sleep(for: .milliseconds(50))
        }

        let messageCountBefore = viewModel.messages.count

        // 終了後に送信しても変わらない
        viewModel.inputText = "もう1つ"
        viewModel.sendMessage()
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.messages.count == messageCountBefore)
    }

    // MARK: - 会話履歴

    @Test func testConversationHistoryPassedToRepository() async throws {
        let mockRepo = MockTextGenerationRepository()
        mockRepo.response = "返答なのだ"

        let viewModel = ChatViewModel(
            textGenerationRepository: mockRepo,
            voicevoxRepository: MockTextToSpeechRepository()
        )

        viewModel.inputText = "1つ目"
        viewModel.sendMessage()
        try await Task.sleep(for: .milliseconds(100))

        viewModel.inputText = "2つ目"
        viewModel.sendMessage()
        try await Task.sleep(for: .milliseconds(100))

        // 2回目の呼び出し時にはシステム + 1回目のやりとり + 2回目のユーザーメッセージが渡される
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
