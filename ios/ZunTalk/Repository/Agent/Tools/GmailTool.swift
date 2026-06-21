import Foundation

/// Gmail API を端末から叩いて、直近のメールを要約テキストで返す。
enum GmailTool {
    static func fetch(accessToken: String, query: String) async throws -> String {
        // 1) 最近のメール ID を取得
        var listComps = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        listComps.queryItems = [
            URLQueryItem(name: "maxResults", value: "5"),
            URLQueryItem(name: "q", value: "in:inbox")
        ]
        var listRequest = URLRequest(url: listComps.url!)
        listRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (listData, listResponse) = try await URLSession.shared.data(for: listRequest)
        if let http = listResponse as? HTTPURLResponse, http.statusCode != 200 {
            throw AgentToolError.api("Gmail", http.statusCode)
        }
        let list = try JSONDecoder().decode(GmailListResponse.self, from: listData)
        guard let messages = list.messages, !messages.isEmpty else {
            return "最近のメールはありません。"
        }

        // 2) 各メールの件名・差出人・スニペットを取得
        var lines: [String] = []
        for message in messages.prefix(5) {
            if let line = try? await fetchSummary(id: message.id, accessToken: accessToken) {
                lines.append(line)
            }
        }
        return lines.isEmpty ? "メールの取得に失敗しました。" : lines.joined(separator: "\n")
    }

    private static func fetchSummary(id: String, accessToken: String) async throws -> String {
        var comps = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)")!
        comps.queryItems = [
            URLQueryItem(name: "format", value: "metadata"),
            URLQueryItem(name: "metadataHeaders", value: "Subject"),
            URLQueryItem(name: "metadataHeaders", value: "From")
        ]
        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)
        let headers = message.payload?.headers ?? []
        let subject = headers.first { $0.name == "Subject" }?.value ?? "(件名なし)"
        let from = headers.first { $0.name == "From" }?.value ?? ""
        let snippet = message.snippet ?? ""
        return "・[\(from)] \(subject) — \(snippet.prefix(40))"
    }
}

private struct GmailListResponse: Codable {
    let messages: [Reference]?
    struct Reference: Codable { let id: String }
}

private struct GmailMessage: Codable {
    let snippet: String?
    let payload: Payload?

    struct Payload: Codable {
        let headers: [Header]?
    }
    struct Header: Codable {
        let name: String
        let value: String
    }
}
