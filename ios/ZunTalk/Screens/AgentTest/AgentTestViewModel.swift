import Foundation

/// エージェント結線の検証用 ViewModel。発話を送って plan / results / reply を表示する。
@MainActor
final class AgentTestViewModel: ObservableObject {
    @Published var input = ""
    @Published var isRunning = false
    @Published var planText = ""
    @Published var resultsText = ""
    @Published var reply = ""
    @Published var errorText = ""

    private let repository = AgentRepository()

    func send() async {
        let message = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        isRunning = true
        planText = ""
        resultsText = ""
        reply = ""
        errorText = ""
        defer { isRunning = false }

        do {
            let result = try await repository.run(message: message)
            planText = result.plan
                .map { "・\($0.capability): \($0.query)" }
                .joined(separator: "\n")
            resultsText = result.results
                .map { "[\($0.capability)]\n\($0.error.map { "⚠️ " + $0 } ?? $0.content)" }
                .joined(separator: "\n\n")
            reply = result.reply
        } catch {
            errorText = error.localizedDescription
        }
    }
}
