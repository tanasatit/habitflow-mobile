import Fluent

struct CreateCalendarEvent: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("calendar_events")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("title", .string, .required)
            .field("notes", .string)
            .field("start_at", .datetime, .required)
            .field("end_at", .datetime, .required)
            .field("all_day", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("calendar_events").delete()
    }
}
