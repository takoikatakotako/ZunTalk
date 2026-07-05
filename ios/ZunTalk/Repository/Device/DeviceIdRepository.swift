import Foundation

/// 端末を一意に識別する UUID を管理する。
/// サーバー（電話予約 API）が端末を識別するためのキーで、Keychain に永続化する
/// （アプリを再インストールしても保持される）。
final class DeviceIdRepository {
    static let shared = DeviceIdRepository()

    private static let key = "device-uuid"
    private let keychain = KeychainRepository.shared

    private init() {}

    /// 端末IDを返す。未生成なら生成して Keychain に保存する。
    func deviceId() -> String {
        if let existing = try? keychain.get(key: Self.key) {
            return existing
        }
        let newId = UUID().uuidString
        try? keychain.save(key: Self.key, value: newId)
        return newId
    }
}
