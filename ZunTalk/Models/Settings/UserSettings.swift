import Foundation

class UserSettings: ObservableObject {
    static let shared = UserSettings()

    private static let openAIAPIKeyKeychainKey = "com.zuntalk.openai.apikey"

    @Published var selectedModelType: AIModelType {
        didSet {
            UserDefaults.standard.set(selectedModelType.rawValue, forKey: "selectedModelType")
        }
    }

    @Published var openAIAPIKey: String {
        didSet {
            keychainError = nil
            do {
                if openAIAPIKey.isEmpty {
                    try KeychainRepository.shared.delete(key: Self.openAIAPIKeyKeychainKey)
                } else {
                    try KeychainRepository.shared.save(key: Self.openAIAPIKeyKeychainKey, value: openAIAPIKey)
                }
            } catch {
                print("Keychainへの保存エラー: \(error.localizedDescription)")
                keychainError = error
                openAIAPIKey = "" // 失敗時は空にする
            }
        }
    }

    @Published var keychainError: Error?

    var hasOpenAIAPIKey: Bool {
        !openAIAPIKey.isEmpty
    }

    private init() {
        let savedValue = UserDefaults.standard.string(forKey: "selectedModelType")
        self.selectedModelType = savedValue.flatMap { AIModelType(rawValue: $0) } ?? .freeServer

        // Keychainから読み込み
        self.openAIAPIKey = (try? KeychainRepository.shared.get(key: Self.openAIAPIKeyKeychainKey)) ?? ""
    }

    func deleteOpenAIAPIKey() {
        openAIAPIKey = ""
        try? KeychainRepository.shared.delete(key: Self.openAIAPIKeyKeychainKey)
    }
}
