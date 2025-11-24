import Foundation

class UserSettings: ObservableObject {
    static let shared = UserSettings()

    @Published var selectedModelType: AIModelType {
        didSet {
            UserDefaults.standard.set(selectedModelType.rawValue, forKey: "selectedModelType")
        }
    }

    @Published var openAIAPIKey: String {
        didSet {
            // セキュリティのため、Keychainに保存するのが理想的ですが、
            // 現時点ではUserDefaultsを使用
            UserDefaults.standard.set(openAIAPIKey, forKey: "openAIAPIKey")
        }
    }

    var hasOpenAIAPIKey: Bool {
        !openAIAPIKey.isEmpty
    }

    private init() {
        let savedValue = UserDefaults.standard.string(forKey: "selectedModelType")
        self.selectedModelType = savedValue.flatMap { AIModelType(rawValue: $0) } ?? .freeServer

        self.openAIAPIKey = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
    }

    func deleteOpenAIAPIKey() {
        openAIAPIKey = ""
        UserDefaults.standard.removeObject(forKey: "openAIAPIKey")
    }
}
