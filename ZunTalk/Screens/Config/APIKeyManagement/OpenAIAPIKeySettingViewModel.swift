import Foundation

@MainActor
class OpenAIAPIKeySettingViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var showPassword: Bool = false
    @Published var keychainError: Error?

    private let settings = UserSettings.shared

    func loadAPIKey() {
        apiKey = settings.openAIAPIKey
    }

    func saveAPIKey() {
        settings.openAIAPIKey = apiKey
        keychainError = settings.keychainError
    }

    func togglePasswordVisibility() {
        showPassword.toggle()
    }

    var isSaveButtonDisabled: Bool {
        apiKey.isEmpty
    }
}
