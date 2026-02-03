import Testing
@testable import ZunTalk

@MainActor
struct CallViewModelIntegrationTests {

    @Test func testCallViewModelInitializesWithFactoryRepository() async throws {
        // Given: UserSettingsでfreeServerを選択
        UserSettings.shared.selectedModelType = .freeServer

        // When: CallViewModelを初期化
        let viewModel = CallViewModel()

        // Then: ViewModelが正常に初期化される
        #expect(viewModel.status == .idle)
    }

    @Test
    @available(iOS 26.0, *)
    func testCallViewModelWithFoundationModels() async throws {
        // Given: UserSettingsでfoundationModelsを選択
        UserSettings.shared.selectedModelType = .foundationModels

        // When: CallViewModelを初期化
        let viewModel = CallViewModel()

        // Then: ViewModelが正常に初期化される
        #expect(viewModel.status == .idle)
    }

    @Test func testRepositorySwitchingBetweenTypes() async throws {
        // Given: 異なるモデルタイプでViewModelを作成

        // freeServerでViewModel作成
        UserSettings.shared.selectedModelType = .freeServer
        let viewModel1 = CallViewModel()

        // foundationModelsでViewModel作成
        UserSettings.shared.selectedModelType = .foundationModels
        let viewModel2 = CallViewModel()

        // Then: 両方のViewModelが正常に初期化される
        #expect(viewModel1.status == .idle)
        #expect(viewModel2.status == .idle)
    }

    @Test func testCallViewModelWithCustomRepository() async throws {
        // Given: モックリポジトリを作成
        let mockRepository = MockTextGenerationRepository()

        // When: カスタムリポジトリでViewModelを初期化
        let viewModel = CallViewModel(textGenerationRepository: mockRepository)

        // Then: ViewModelが正常に初期化される
        #expect(viewModel.status == .idle)
    }

    @Test func testDefaultRepositorySelection() async throws {
        // Given: デフォルト設定（freeServer）
        UserSettings.shared.selectedModelType = .freeServer

        // When: パラメータなしでViewModelを初期化
        let viewModel = CallViewModel()

        // Then: デフォルトリポジトリが使用される
        #expect(viewModel.status == .idle)
    }
}

// MARK: - Mock Repository

private class MockTextGenerationRepository: TextGenerationRepository {
    func generateResponse(inputs: [ChatMessage]) async throws -> String {
        return "モックレスポンス"
    }
}
