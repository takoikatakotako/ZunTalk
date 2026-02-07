import Testing
@testable import ZunTalk

#if canImport(FoundationModels)
struct FoundationModelsTextGenerationRepositoryTests {

    @Test
    @available(iOS 26.0, *)
    func testRepositoryInitialization() async throws {
        // Given & When: リポジトリを初期化
        let repository = FoundationModelsTextGenerationRepository()

        // Then: エラーなく初期化される
        #expect(repository != nil)
    }

    @Test
    @available(iOS 26.0, *)
    func testSimpleGeneration() async throws {
        // Given: リポジトリとシンプルなメッセージ
        let repository = FoundationModelsTextGenerationRepository()

        let messages = [
            ChatMessage(role: .system, content: "あなたはずんだもんです。"),
            ChatMessage(role: .user, content: "こんにちは！")
        ]

        // When: 応答を生成
        let response = try await repository.generateResponse(inputs: messages)

        // Then: 空でないレスポンスが返される
        #expect(!response.isEmpty)
        #expect(response.count > 0)
    }

    @Test
    @available(iOS 26.0, *)
    func testConversationHistory() async throws {
        // Given: 会話履歴を含むメッセージ
        let repository = FoundationModelsTextGenerationRepository()

        let messages = [
            ChatMessage(role: .system, content: "あなたはずんだもんです。"),
            ChatMessage(role: .user, content: "こんにちは！"),
            ChatMessage(role: .assistant, content: "こんにちはなのだ！"),
            ChatMessage(role: .user, content: "元気ですか？")
        ]

        // When: 応答を生成
        let response = try await repository.generateResponse(inputs: messages)

        // Then: 会話コンテキストを考慮した応答が返される
        #expect(!response.isEmpty)
    }

    @Test
    @available(iOS 26.0, *)
    func testEmptyInputHandling() async throws {
        // Given: 空の入力
        let repository = FoundationModelsTextGenerationRepository()

        // When & Then: 空の入力でエラーが発生
        await #expect(throws: FoundationModelsTextGenerationError.self) {
            try await repository.generateResponse(inputs: [])
        }
    }

    @Test
    @available(iOS 26.0, *)
    func testSystemPromptExtraction() async throws {
        // Given: カスタムシステムプロンプト
        let repository = FoundationModelsTextGenerationRepository()

        let customSystemPrompt = "あなたは親切なアシスタントです。"
        let messages = [
            ChatMessage(role: .system, content: customSystemPrompt),
            ChatMessage(role: .user, content: "テストメッセージ")
        ]

        // When: 応答を生成
        let response = try await repository.generateResponse(inputs: messages)

        // Then: システムプロンプトが適用された応答が返される
        #expect(!response.isEmpty)
    }

    @Test
    @available(iOS 26.0, *)
    func testMultipleConsecutiveGenerations() async throws {
        // Given: 同じリポジトリインスタンスで複数回生成
        let repository = FoundationModelsTextGenerationRepository()

        let messages1 = [
            ChatMessage(role: .system, content: "あなたはずんだもんです。"),
            ChatMessage(role: .user, content: "最初の質問")
        ]

        let messages2 = [
            ChatMessage(role: .system, content: "あなたはずんだもんです。"),
            ChatMessage(role: .user, content: "二番目の質問")
        ]

        // When: 連続して応答を生成
        let response1 = try await repository.generateResponse(inputs: messages1)
        let response2 = try await repository.generateResponse(inputs: messages2)

        // Then: 両方の応答が正常に生成される
        #expect(!response1.isEmpty)
        #expect(!response2.isEmpty)
    }
}
#endif
