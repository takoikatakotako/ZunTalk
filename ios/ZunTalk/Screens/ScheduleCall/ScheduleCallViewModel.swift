import Foundation
import AVFoundation
import Speech

@MainActor
class ScheduleCallViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedDate = Date().addingTimeInterval(Constants.minimumLeadTime)
    @Published var calls: [ScheduledCall] = []
    @Published var isLoading = false
    @Published var isScheduling = false
    @Published var errorMessage: String?

    // MARK: - Constants

    private enum Constants {
        /// 予約可能な最短時間（今から2分後）。毎分ポーリングのため直近すぎる予約は取りこぼす。
        static let minimumLeadTime: TimeInterval = 120
    }

    /// DatePicker の選択可能範囲。
    var selectableRange: ClosedRange<Date> {
        let start = Date().addingTimeInterval(Constants.minimumLeadTime)
        let end = Date().addingTimeInterval(30 * 24 * 60 * 60)
        return start...end
    }

    /// 新しく予約できるか。予約は1件まで（サーバー側でも制限している）。
    var canSchedule: Bool {
        calls.isEmpty
    }

    // MARK: - Private Properties

    private let repository: CallScheduleRepository

    // MARK: - Initialization

    init(repository: CallScheduleRepository = CallScheduleAPIRepository()) {
        self.repository = repository
    }

    // MARK: - Public Methods

    func onAppear() {
        // ロック中の着信応答では許可ダイアログを出せないため、予約の時点で
        // マイク・音声認識の許可を取っておく
        Task {
            await requestPermissions()
        }
        Task {
            await refreshDeviceRegistration()
            await loadCalls()
        }
    }

    func scheduleCall() async {
        errorMessage = nil
        isScheduling = true
        defer { isScheduling = false }

        do {
            let call = try await repository.scheduleCall(at: selectedDate)
            calls.append(call)
            calls.sort { ($0.scheduledDate ?? .distantFuture) < ($1.scheduledDate ?? .distantFuture) }
        } catch {
            print("予約作成エラー: \(error)")
            errorMessage = scheduleErrorMessage(from: error)
        }
    }

    func cancelCall(_ call: ScheduledCall) async {
        errorMessage = nil
        do {
            try await repository.cancelCall(id: call.id)
            calls.removeAll { $0.id == call.id }
        } catch {
            print("予約キャンセルエラー: \(error)")
            errorMessage = "予約のキャンセルに失敗したのだ"
        }
    }

    // MARK: - Private Methods

    private func loadCalls() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 未発火の予約だけ表示する（sent/canceled 等の履歴は出さない）
            calls = try await repository.fetchCalls().filter { $0.isCancellable }
        } catch {
            print("予約一覧取得エラー: \(error)")
            errorMessage = "予約一覧の取得に失敗したのだ"
        }
    }

    /// VoIP トークンをサーバーに再登録する（冪等）。
    /// 起動時の自動登録が失敗していた場合のリカバリを兼ねる。
    private func refreshDeviceRegistration() async {
        guard let token = VoIPPushManager.shared.voipToken else {
            // シミュレータ等では VoIP トークンが取れない
            errorMessage = "この端末では着信の準備ができていないのだ（実機で試してほしいのだ）"
            return
        }
        do {
            try await repository.registerDevice(voipToken: token)
        } catch {
            print("端末登録エラー: \(error)")
            errorMessage = "端末の登録に失敗したのだ"
        }
    }

    private func requestPermissions() async {
        if AVAudioApplication.shared.recordPermission == .undetermined {
            _ = await AVAudioApplication.requestRecordPermission()
        }
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in
                    continuation.resume()
                }
            }
        }
    }

    private func scheduleErrorMessage(from error: Error) -> String {
        if case CallScheduleError.api(let code, _) = error {
            switch code {
            case 400:
                return "予約内容が正しくないのだ（時刻や件数の上限を確認してほしいのだ）"
            default:
                break
            }
        }
        return "予約の作成に失敗したのだ"
    }
}
