import Fluent

struct CreateHabit: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("habits")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("category", .string)
            .field("frequency", .string, .required)
            .field("target_time", .string)
            .field("description", .string)
            .field("is_active", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("habits").delete()
    }
}
