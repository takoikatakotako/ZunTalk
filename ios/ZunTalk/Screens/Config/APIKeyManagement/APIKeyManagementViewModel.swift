import Foundation

@MainActor
class APIKeyManagementViewModel: ObservableObject {
    @Published var hasOpenAIAPIKey: Bool

    private let settings = UserSettings.shared

    init() {
        self.hasOpenAIAPIKey = settings.hasOpenAIAPIKey
    }

    func deleteOpenAIAPIKey() {
        settings.deleteOpenAIAPIKey()
        hasOpenAIAPIKey = false
    }

    func updateAPIKeyStatus() {
        hasOpenAIAPIKey = settings.hasOpenAIAPIKey
    }
}
