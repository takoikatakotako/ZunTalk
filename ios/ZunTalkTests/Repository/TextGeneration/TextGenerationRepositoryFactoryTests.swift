import Testing
@testable import ZunTalk

struct TextGenerationRepositoryFactoryTests {

    @Test func testFactoryCreatesFreeServerRepository() async throws {
        // Given: モデルタイプがfreeServerに設定されている
        UserSettings.shared.selectedModelType = .freeServer

        // When: Factoryからリポジトリを作成
        let repository = TextGenerationRepositoryFactory.create()

        // Then: OpenAITextGenerationRepositoryが返される
        #expect(repository is OpenAITextGenerationRepository)
    }

    #if canImport(FoundationModels)
    @Test
    @available(iOS 26.0, *)
    func testFactoryCreatesFoundationModelsRepositoryOnIOS26() async throws {
        // Given: モデルタイプがfoundationModelsに設定されている
        UserSettings.shared.selectedModelType = .foundationModels

        // When: Factoryからリポジトリを作成
        let repository = TextGenerationRepositoryFactory.create()

        // Then: FoundationModelsTextGenerationRepositoryが返される
        #expect(repository is FoundationModelsTextGenerationRepository)
    }
    #endif

    @Test func testFactoryFallbackToFreeServerOnUnsupportedOS() async throws {
        // このテストはiOS 26未満の環境で実行される
        guard #unavailable(iOS 26.0) else {
            // iOS 26+では実行しない
            return
        }

        // Given: モデルタイプがfoundationModelsに設定されている
        UserSettings.shared.selectedModelType = .foundationModels

        // When: Factoryからリポジトリを作成
        let repository = TextGenerationRepositoryFactory.create()

        // Then: フォールバックとしてOpenAITextGenerationRepositoryが返される
        #expect(repository is OpenAITextGenerationRepository)
    }
}
