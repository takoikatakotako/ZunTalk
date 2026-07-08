import Foundation
import EventKit

/// EventKit（iOS 標準カレンダーの端末内 DB）から直近の予定を要約テキストで返す。
///
/// ユーザーが iOS 設定に Google アカウントを追加していれば Google カレンダーの
/// 予定も同期済みで読める。端末内で完結するため Google の OAuth・審査は不要。
/// 返却文字列の形式（`・<when> <summary>` を改行結合）はサーバーの responder が
/// そのまま読む契約なので変更しないこと。
enum CalendarTool {

    private enum Constants {
        /// 何日先までの予定を対象にするか。
        static let horizonDays = 7
        /// 返す予定の最大件数。
        static let maxEvents = 10
    }

    static func fetch(query: String) async throws -> String {
        let store = EKEventStore()

        // カレンダーへのアクセス許可を確認（未決定ならダイアログを出す）
        guard await requestAccessIfNeeded(store: store) else {
            throw CalendarToolError.accessDenied
        }

        let now = Date()
        guard let end = Calendar.current.date(byAdding: .day, value: Constants.horizonDays, to: now) else {
            throw CalendarToolError.invalidDateRange
        }

        // calendars: nil = 同期されている全アカウントのカレンダーが対象
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(Constants.maxEvents)

        guard !events.isEmpty else {
            var message = "今後の予定はありません。"
            if !hasGoogleCalendarSource(store: store) {
                message += "（メモ: この iPhone には Google アカウントのカレンダーが同期されていません。"
                message += "設定 > アプリ > カレンダー > アカウント から追加すると Google カレンダーの予定も確認できます）"
            }
            return message
        }

        return events.map { event in
            "・\(format(event)) \(event.title ?? "(無題)")"
        }.joined(separator: "\n")
    }

    // MARK: - Private

    /// アクセス許可を確認し、未決定ならリクエストする。許可があれば true。
    private static func requestAccessIfNeeded(store: EKEventStore) async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .notDetermined:
            return (try? await store.requestFullAccessToEvents()) ?? false
        case .denied, .restricted, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }

    /// Google アカウントのカレンダー（CalDAV）が同期されているか。
    private static func hasGoogleCalendarSource(store: EKEventStore) -> Bool {
        store.sources.contains { source in
            source.sourceType == .calDAV && source.title.localizedCaseInsensitiveContains("google")
        }
    }

    /// 予定の日時を読みやすい形式にする（終日イベントは日付のみ）。
    private static func format(_ event: EKEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = event.isAllDay ? "M/d(E)" : "M/d(E) HH:mm"
        return formatter.string(from: event.startDate)
    }
}

enum CalendarToolError: Error, LocalizedError {
    case accessDenied
    case invalidDateRange

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "カレンダーへのアクセスが許可されていません。iOS の設定アプリから「ずんトーク」にカレンダーのフルアクセスを許可してください。"
        case .invalidDateRange:
            return "予定の検索期間を計算できませんでした。"
        }
    }
}
