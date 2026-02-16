import Foundation
import Network

class NetworkRepository: NetworkRepositoryProtocol {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkConnected = true

    init() {
        startMonitoring()
    }

    /// ネットワーク監視を開始
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkConnected = path.status == .satisfied
        }
        monitor.start(queue: queue)
    }

    /// ネットワーク接続状態をチェック
    func isConnected() -> Bool {
        return isNetworkConnected
    }

    deinit {
        monitor.cancel()
    }
}
