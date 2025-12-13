import Foundation

/// Lambda API /api/info のレスポンス
struct AppInfoResponse: Codable {
    let maintenance: Bool
    let minimumVersion: String
}
