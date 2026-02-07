import Foundation

struct TextGenerationRepositoryFactory {

    static func create() -> TextGenerationRepository {
        let modelType = UserSettings.shared.selectedModelType

        switch modelType {
        case .freeServer:
            return OpenAITextGenerationRepository()

        case .foundationModels:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                return FoundationModelsTextGenerationRepository()
            } else {
                print("⚠️ Foundation Models requires iOS 26+, falling back to free server")
                return OpenAITextGenerationRepository()
            }
            #else
            print("⚠️ Foundation Models not available, falling back to free server")
            return OpenAITextGenerationRepository()
            #endif
        }
    }
}
