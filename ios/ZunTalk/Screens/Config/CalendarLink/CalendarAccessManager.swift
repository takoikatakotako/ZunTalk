import EventKit
import Foundation

/// 設定画面向けに、iOS 標準カレンダー（EventKit）へのアクセス許可状態を管理する。
///
/// エージェントのカレンダーツールは EventKit で端末内のカレンダーを読む。
/// 実際の読み取り時にも権限は要求されるが、事前に設定画面から許可・状態確認できるようにする。
@MainActor
final class CalendarAccessManager: ObservableObject {
    static let shared = CalendarAccessManager()

    /// 許可の状態。
    enum Status {
        /// フルアクセス許可済み。
        case authorized
        /// 未決定（まだダイアログを出していない）。
        case notDetermined
        /// 拒否・制限・書き込みのみ（設定アプリから変更が必要）。
        case denied

        var isAuthorized: Bool { self == .authorized }
    }

    @Published private(set) var status: Status = .notDetermined
    @Published private(set) var isRequesting = false

    private let store = EKEventStore()

    private init() {
        refresh()
    }

    /// 現在の許可状態を EventKit から読み直す。
    func refresh() {
        status = Self.mapStatus(EKEventStore.authorizationStatus(for: .event))
    }

    /// 未決定ならアクセス許可ダイアログを出す。結果を状態に反映する。
    func requestAccess() async {
        guard case .notDetermined = status else { return }
        isRequesting = true
        defer { isRequesting = false }
        _ = try? await store.requestFullAccessToEvents()
        refresh()
    }

    private static func mapStatus(_ status: EKAuthorizationStatus) -> Status {
        switch status {
        case .fullAccess:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted, .writeOnly:
            return .denied
        @unknown default:
            return .denied
        }
    }
}
