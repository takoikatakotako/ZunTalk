import Foundation

protocol NetworkRepositoryProtocol {
    /// ネットワーク接続状態をチェック
    /// - Returns: ネットワークに接続されている場合はtrue
    func isConnected() -> Bool
}
