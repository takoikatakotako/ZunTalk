import Foundation

/// Google Calendar API を端末から叩いて、直近の予定を要約テキストで返す。
enum CalendarTool {
    static func fetch(accessToken: String, query: String) async throws -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        var comps = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        comps.queryItems = [
            URLQueryItem(name: "timeMin", value: now),
            URLQueryItem(name: "maxResults", value: "10"),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw AgentToolError.api("Calendar", http.statusCode)
        }

        let decoded = try JSONDecoder().decode(CalendarEventsResponse.self, from: data)
        guard !decoded.items.isEmpty else {
            return "今後の予定はありません。"
        }
        return decoded.items.prefix(10).map { event in
            let when = event.start?.dateTime ?? event.start?.date ?? "(日時不明)"
            return "・\(when) \(event.summary ?? "(無題)")"
        }.joined(separator: "\n")
    }
}

private struct CalendarEventsResponse: Codable {
    let items: [Event]

    struct Event: Codable {
        let summary: String?
        let start: When?

        struct When: Codable {
            let dateTime: String?
            let date: String?
        }
    }
}
