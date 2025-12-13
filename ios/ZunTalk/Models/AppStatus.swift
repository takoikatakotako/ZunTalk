import Foundation

/// アプリの起動時ステータス
enum AppStatus {
    case loading
    case ready
    case maintenance
    case updateRequired(currentVersion: String, minimumVersion: String)
    case error(String)
}
