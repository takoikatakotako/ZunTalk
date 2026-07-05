import Foundation

/// 電話予約 API（Cloud Run）へのアクセスを抽象化する。
protocol CallScheduleRepository {
    /// VoIP トークンをサーバーに登録する（冪等）。
    func registerDevice(voipToken: String) async throws
    /// 指定時刻の電話を予約する。
    func scheduleCall(at date: Date) async throws -> ScheduledCall
    /// この端末の予約一覧を取得する。
    func fetchCalls() async throws -> [ScheduledCall]
    /// 予約をキャンセルする。
    func cancelCall(id: String) async throws
}

/// Cloud Run の電話予約 API を叩く実装。
final class CallScheduleAPIRepository: CallScheduleRepository {
    private let deviceIdRepository: DeviceIdRepository

    init(deviceIdRepository: DeviceIdRepository = .shared) {
        self.deviceIdRepository = deviceIdRepository
    }

    func registerDevice(voipToken: String) async throws {
        let body = RegisterDeviceRequest(
            deviceId: deviceIdRepository.deviceId(),
            voipToken: voipToken,
            apnsEnv: VoIPPushManager.apnsEnvironment,
            bundleId: Bundle.main.bundleIdentifier ?? ""
        )
        _ = try await request(path: "/devices", method: "PUT", body: body)
    }

    func scheduleCall(at date: Date) async throws -> ScheduledCall {
        let body = CreateCallRequest(
            deviceId: deviceIdRepository.deviceId(),
            scheduledAt: ISO8601DateFormatter().string(from: date)
        )
        let data = try await request(path: "/calls", method: "POST", body: body)
        return try JSONDecoder().decode(ScheduledCall.self, from: data)
    }

    func fetchCalls() async throws -> [ScheduledCall] {
        let deviceId = deviceIdRepository.deviceId()
        let data = try await request(path: "/calls?deviceId=\(deviceId)", method: "GET")
        return try JSONDecoder().decode(ListCallsResponse.self, from: data).calls
    }

    func cancelCall(id: String) async throws {
        let deviceId = deviceIdRepository.deviceId()
        _ = try await request(path: "/calls/\(id)?deviceId=\(deviceId)", method: "DELETE")
    }

    // MARK: - Private

    private func request(path: String, method: String, body: Encodable? = nil) async throws -> Data {
        guard let url = URL(string: AgentConfig.baseURL + path) else {
            throw CallScheduleError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        let apiKey = AgentConfig.apiKey
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw CallScheduleError.api(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}

enum CallScheduleError: Error, LocalizedError {
    case invalidURL
    case api(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "予約APIの URL が不正なのだ"
        case .api(let code, let body):
            return "予約APIエラー(\(code)): \(body)"
        }
    }
}
