import Foundation
import PushKit

/// PushKit（VoIP push）の登録と受信を担当するシングルトン。
///
/// VoIP push はアプリが終了していてもバックグラウンド起動して届くため、
/// アプリ起動直後（AppDelegate）に必ず register() を呼んでデリゲートを立てておく。
final class VoIPPushManager: NSObject {
    static let shared = VoIPPushManager()

    /// 最新の VoIP デバイストークン（hex）。
    private(set) var voipToken: String?

    /// トークンが更新されたときに呼ばれる（サーバーへの登録用フック）。
    var onTokenUpdate: ((String) -> Void)?

    private var registry: PKPushRegistry?

    override private init() {
        super.init()
    }

    func register() {
        let registry = PKPushRegistry(queue: .main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        self.registry = registry
    }

    /// 現在の APNs 環境。Debug ビルド＝開発証明書＝sandbox。
    static var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}

// MARK: - PKPushRegistryDelegate

extension VoIPPushManager: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        voipToken = token
        // 実機テスト時に cmd/apns-push へ渡すトークンをここから拾う
        print("VoIP token (\(Self.apnsEnvironment)): \(token)")
        onTokenUpdate?(token)
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }
        // Apple の規約: VoIP push を受けたら（キャンセル済み等でも）必ず着信を報告する。
        // 報告しないとアプリが terminate され、以後 VoIP push が届かなくなる。
        let callID = payload.dictionaryPayload["callId"] as? String ?? UUID().uuidString
        CallKitManager.shared.reportIncomingCall(callID: callID, completion: completion)
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        voipToken = nil
        print("VoIP token invalidated")
    }
}
