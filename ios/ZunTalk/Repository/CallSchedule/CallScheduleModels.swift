import Foundation

/// PUT /devices のリクエスト。
struct RegisterDeviceRequest: Encodable {
    let deviceId: String
    let voipToken: String
    let apnsEnv: String
    let bundleId: String
}

/// POST /calls のリクエスト。
struct CreateCallRequest: Encodable {
    let deviceId: String
    /// RFC3339（例: "2026-07-08T22:30:00Z"）。
    let scheduledAt: String
}

/// 電話の予約1件。
struct ScheduledCall: Decodable, Identifiable, Equatable {
    let id: String
    let deviceId: String
    /// RFC3339 (UTC)。
    let scheduledAt: String
    let status: String

    /// 予約時刻を Date に変換したもの。
    var scheduledDate: Date? {
        ISO8601DateFormatter().date(from: scheduledAt)
    }

    /// キャンセル可能（未発火）かどうか。
    var isCancellable: Bool {
        status == "scheduled"
    }
}

/// GET /calls のレスポンス。
struct ListCallsResponse: Decodable {
    let calls: [ScheduledCall]
}
