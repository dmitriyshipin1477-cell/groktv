import Foundation

/// A single message shown in the chat transcript and sent as conversation history.
struct ChatMessage: Identifiable, Equatable, Codable, Sendable {
    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }

    /// Wire representation for the chat completions API.
    var apiMessage: APIMessage {
        APIMessage(role: role.rawValue, content: content)
    }
}
