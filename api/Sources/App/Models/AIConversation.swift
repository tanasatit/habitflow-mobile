import Vapor
import Fluent

struct StoredMessage: Codable, Sendable {
    let role: String   // "user" or "model"
    let text: String
}

final class AIConversation: Model, @unchecked Sendable {
    static let schema = "ai_conversations"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "messages_json")
    var messagesJSON: String

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(userID: UUID) {
        self.$user.id = userID
        self.messagesJSON = "[]"
    }
}
