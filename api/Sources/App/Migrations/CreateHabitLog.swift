import Fluent

struct CreateHabitLog: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("habit_logs")
            .id()
            .field("habit_id", .uuid, .required, .references("habits", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("completed_at", .datetime, .required)
            .field("notes", .string)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("habit_logs").delete()
    }
}
