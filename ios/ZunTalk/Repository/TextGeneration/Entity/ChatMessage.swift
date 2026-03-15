import Foundation

struct ChatMessage: Codable {
    let role: String
    let content: String

    enum Role: String {
        case system
        case user
        case assistant
    }

    init(role: Role, content: String) {
        self.role = role.rawValue
        self.content = content
    }
}
