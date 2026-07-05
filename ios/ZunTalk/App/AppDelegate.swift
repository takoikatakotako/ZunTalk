import UIKit

/// PushKit（VoIP push）の登録のために最小限の AppDelegate を用意する。
/// VoIP push はアプリ終了中でもバックグラウンド起動して届くため、
/// 起動直後にデリゲートを立てておく必要がある。
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // トークンが更新されたらサーバーに再登録する（冪等）
        VoIPPushManager.shared.onTokenUpdate = { token in
            Task {
                do {
                    try await CallScheduleAPIRepository().registerDevice(voipToken: token)
                } catch {
                    print("VoIP トークンの登録に失敗: \(error)")
                }
            }
        }
        VoIPPushManager.shared.register()
        return true
    }
}
