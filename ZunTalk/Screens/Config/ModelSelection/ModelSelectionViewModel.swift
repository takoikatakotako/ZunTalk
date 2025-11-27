import Foundation

@MainActor
class ModelSelectionViewModel: ObservableObject {
    @Published var selectedModelType: AIModelType
    @Published var hasOpenAIAPIKey: Bool

    private let settings = UserSettings.shared

    init() {
        self.selectedModelType = settings.selectedModelType
        self.hasOpenAIAPIKey = settings.hasOpenAIAPIKey
    }

    func selectModel(_ modelType: AIModelType) {
        selectedModelType = modelType
        settings.selectedModelType = modelType
    }

    func updateAPIKeyStatus() {
        hasOpenAIAPIKey = settings.hasOpenAIAPIKey
    }
}
