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
            do {
                if openAIAPIKey.isEmpty {
                    try? KeychainRepository.shared.delete(key: Self.openAIAPIKeyKeychainKey)
                } else {
                    try KeychainRepository.shared.save(key: Self.openAIAPIKeyKeychainKey, value: openAIAPIKey)
                }
            } catch {
                print("Keychainへの保存エラー: \(error.localizedDescription)")
            }
        }
    }

    var hasOpenAIAPIKey: Bool {
        !openAIAPIKey.isEmpty
    }

    private init() {
        let savedValue = UserDefaults.standard.string(forKey: "selectedModelType")
        self.selectedModelType = savedValue.flatMap { AIModelType(rawValue: $0) } ?? .freeServer

        // UserDefaultsからの移行処理
        if let oldAPIKey = UserDefaults.standard.string(forKey: "openAIAPIKey"), !oldAPIKey.isEmpty {
            // 古いUserDefaultsのデータをKeychainに移行
            try? KeychainRepository.shared.save(key: Self.openAIAPIKeyKeychainKey, value: oldAPIKey)
            UserDefaults.standard.removeObject(forKey: "openAIAPIKey")
            self.openAIAPIKey = oldAPIKey
        } else {
            // Keychainから読み込み
            self.openAIAPIKey = (try? KeychainRepository.shared.get(key: Self.openAIAPIKeyKeychainKey)) ?? ""
        }
    }

    func deleteOpenAIAPIKey() {
        openAIAPIKey = ""
        try? KeychainRepository.shared.delete(key: Self.openAIAPIKeyKeychainKey)
    }
}
