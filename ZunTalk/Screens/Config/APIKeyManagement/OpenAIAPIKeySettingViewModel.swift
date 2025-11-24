import Foundation

@MainActor
class OpenAIAPIKeySettingViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var showPassword: Bool = false

    private let settings = UserSettings.shared

    func loadAPIKey() {
        apiKey = settings.openAIAPIKey
    }

    func saveAPIKey() {
        settings.openAIAPIKey = apiKey
    }

    func togglePasswordVisibility() {
        showPassword.toggle()
    }

    var isSaveButtonDisabled: Bool {
        apiKey.isEmpty
    }
}
