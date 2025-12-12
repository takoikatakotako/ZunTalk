import Foundation

enum APIConfig {
    /// API Base URL（.xcconfigから読み込み）
    static var baseURL: String {
        // Build Settingsから読み込む
        // Info Dictionaryの全キーをデバッグ出力
        #if DEBUG
        print("=== Info Dictionary Keys ===")
        if let infoDict = Bundle.main.infoDictionary {
            for (key, value) in infoDict {
                if key.contains("API") || key.contains("URL") {
                    print("\(key): \(value)")
                }
            }
        }
        #endif

        // 複数のキー名を試す
        let possibleKeys = ["API_BASE_URL", "APIBaseURL", "INFOPLIST_KEY_API_BASE_URL"]
        for key in possibleKeys {
            if let urlString = Bundle.main.object(forInfoDictionaryKey: key) as? String {
                print("Found API_BASE_URL with key: \(key) = \(urlString)")
                return urlString
            }
        }

        fatalError("API_BASE_URL not found in Info Dictionary. Tried keys: \(possibleKeys)")
    }

    /// Chat API エンドポイント
    static var chatEndpoint: String {
        return "\(baseURL)/api/chat"
    }

    /// Info API エンドポイント
    static var infoEndpoint: String {
        return "\(baseURL)/api/info"
    }

    /// Health Check エンドポイント
    static var healthEndpoint: String {
        return "\(baseURL)/health"
    }
}
