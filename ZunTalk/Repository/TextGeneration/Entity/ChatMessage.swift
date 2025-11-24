import Foundation

struct ChatMessage: Codable {
    let role: String
    let content: String
    
    enum Role: String {
        case system = "system"
        case user = "user"
        case assistant = "assistant"
    }
    
    init(role: Role, content: String) {
        self.role = role.rawValue
        self.content = content
    }
}