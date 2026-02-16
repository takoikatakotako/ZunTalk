import Foundation
import UIKit

@MainActor
class LaunchViewModel: ObservableObject {
    @Published var appStatus: AppStatus = .loading

    private let appInfoRepository: AppInfoRepositoryProtocol
    private let networkRepository: NetworkRepositoryProtocol

    init(
        appInfoRepository: AppInfoRepositoryProtocol = AppInfoRepository(),
        networkRepository: NetworkRepositoryProtocol = NetworkRepository()
    ) {
        self.appInfoRepository = appInfoRepository
        self.networkRepository = networkRepository
    }

    func checkAppStatus() async {
        appStatus = .loading

        // UIテスト時はAPI呼び出しをスキップ
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("SKIP-API-CALLS") {
            print("⚠️ [DEBUG] Skipping API calls for UI testing")
            appStatus = .ready
            return
        }
        #endif

        // オフライン時はAPI呼び出しをスキップ（完全オフライン対応）
        if !networkRepository.isConnected() {
            print("📵 Offline mode: Skipping API calls")
            appStatus = .ready
            return
        }

        do {
            let appInfo = try await appInfoRepository.fetchAppInfo()

            // メンテナンス中チェック
            if appInfo.maintenance {
                appStatus = .maintenance
                return
            }

            // バージョンチェック
            let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"

            if isUpdateRequired(currentVersion: currentVersion, minimumVersion: appInfo.minimumVersion) {
                appStatus = .updateRequired(currentVersion: currentVersion, minimumVersion: appInfo.minimumVersion)
                return
            }

            // 正常
            appStatus = .ready
        } catch {
            print("AppInfo fetch error: \(error)")
            // エラー時は一旦アプリを使用可能にする（オフライン対応）
            appStatus = .ready
        }
    }

    /// バージョン比較（セマンティックバージョニング）
    private func isUpdateRequired(currentVersion: String, minimumVersion: String) -> Bool {
        let current = parseVersion(currentVersion)
        let minimum = parseVersion(minimumVersion)

        // メジャーバージョン比較
        if current.major < minimum.major {
            return true
        } else if current.major > minimum.major {
            return false
        }

        // マイナーバージョン比較
        if current.minor < minimum.minor {
            return true
        } else if current.minor > minimum.minor {
            return false
        }

        // パッチバージョン比較
        return current.patch < minimum.patch
    }

    private func parseVersion(_ version: String) -> (major: Int, minor: Int, patch: Int) {
        let components = version.split(separator: ".").compactMap { Int($0) }
        return (
            major: components.count > 0 ? components[0] : 0,
            minor: components.count > 1 ? components[1] : 0,
            patch: components.count > 2 ? components[2] : 0
        )
    }

    /// App Storeを開く
    func openAppStore() {
        // TODO: リリース後にApp Store IDを設定して有効化する
        // let appStoreURL = "https://apps.apple.com/app/idXXXXXXXXXX"
        // if let url = URL(string: appStoreURL) {
        //     UIApplication.shared.open(url)
        // }
    }
}
