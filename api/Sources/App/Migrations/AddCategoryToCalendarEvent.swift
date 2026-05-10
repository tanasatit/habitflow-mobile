import Fluent

struct AddCategoryToCalendarEvent: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("calendar_events")
            .field("category", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("calendar_events")
            .deleteField("category")
            .update()
    }
}
