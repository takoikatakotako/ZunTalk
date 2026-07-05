import Foundation
import CallKit
import AVFoundation
import UIKit

/// CallKit（システム着信 UI）との橋渡しを行うシングルトン。
///
/// - VoIP push 受信時に `reportIncomingCall` でネイティブ着信 UI を表示する
///   （Apple の規約上、VoIP push を受けたら必ず着信を報告する必要がある）
/// - 応答されたら `isPresentingCallScreen` を立て、アプリ側が CallView を全画面表示する
/// - AudioSession のアクティブ化は CallKit が行うため、
///   通話側は `waitForAudioSessionActivation()` でアクティブ化を待ってから録音・再生を始める
final class CallKitManager: NSObject, ObservableObject {
    static let shared = CallKitManager()

    /// 応答済みで通話画面を表示すべきかどうか（ZunTalkApp が fullScreenCover にバインドする）。
    @Published var isPresentingCallScreen = false

    /// システム側（ロック画面の切断ボタン等）から通話が終了されたときに呼ばれる。
    /// CallViewModel が自身のクリーンアップを登録する。
    var onSystemEndCall: (() -> Void)?

    private let provider: CXProvider
    private let callController = CXCallController()

    private var activeCallUUID: UUID?
    private var isAudioSessionActive = false
    private var audioSessionContinuations: [CheckedContinuation<Void, Never>] = []

    override private init() {
        // 表示名にはアプリ名（ずんトーク）が自動で使われる
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = false
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        configuration.iconTemplateImageData = UIImage(resource: .thumbnail).pngData()

        provider = CXProvider(configuration: configuration)
        super.init()
        // queue: nil = メインキューでデリゲートが呼ばれる
        provider.setDelegate(self, queue: nil)
    }

    // MARK: - Incoming Call

    /// VoIP push を受けたら必ず呼ぶ。システムの着信 UI を表示する。
    func reportIncomingCall(callID: String, completion: @escaping () -> Void) {
        let uuid = UUID()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: "ずんだもん")
        update.localizedCallerName = "ずんだもん"
        update.hasVideo = false

        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    // おやすみモード等で着信を出せなかった場合もここに来る
                    print("着信の報告に失敗: \(error.localizedDescription)")
                    CrashlyticsManager.record(error)
                } else {
                    self?.activeCallUUID = uuid
                }
                completion()
            }
        }
    }

    /// アプリ内の切断ボタンから通話を終了する（システムの通話状態を確実にクリアする）。
    func endActiveCall() {
        guard let uuid = activeCallUUID else { return }
        let transaction = CXTransaction(action: CXEndCallAction(call: uuid))
        callController.request(transaction) { error in
            if let error {
                print("通話終了リクエストに失敗: \(error.localizedDescription)")
            }
        }
    }

    /// 会話が自然に終了した（ずんだもんが電話を切った）ことをシステムに通知する。
    /// 通話画面は開いたままにする（ユーザーが切断ボタンで閉じる）。
    func reportRemoteEnded() {
        guard let uuid = activeCallUUID else { return }
        activeCallUUID = nil
        isAudioSessionActive = false
        provider.reportCall(with: uuid, endedAt: nil, reason: .remoteEnded)
    }

    // MARK: - Audio Session

    /// CallKit による AudioSession のアクティブ化を待つ。
    /// 録音・再生を始める前に必ず待つこと（アクティブ化前に始めると無音になる）。
    func waitForAudioSessionActivation() async {
        if isAudioSessionActive { return }
        await withCheckedContinuation { continuation in
            audioSessionContinuations.append(continuation)
        }
    }
}

// MARK: - CXProviderDelegate

extension CallKitManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        activeCallUUID = nil
        isAudioSessionActive = false
        isPresentingCallScreen = false
        onSystemEndCall?()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // CallKit 通話中はカテゴリを固定し、setActive は CallKit に任せる。
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])

        isPresentingCallScreen = true
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        activeCallUUID = nil
        isAudioSessionActive = false
        onSystemEndCall?()
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        isAudioSessionActive = true
        audioSessionContinuations.forEach { $0.resume() }
        audioSessionContinuations.removeAll()
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        isAudioSessionActive = false
    }
}
