import Fluent

struct CreateAIConversation: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("ai_conversations")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("messages_json", .string, .required)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("ai_conversations").delete()
    }
}
