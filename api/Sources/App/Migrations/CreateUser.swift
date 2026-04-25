import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: any Database) async throws {
        let role = try await database.enum("user_role")
            .case("free")
            .case("premium")
            .case("admin")
            .create()

        try await database.schema("users")
            .id()
            .field("email", .string, .required)
            .unique(on: "email")
            .field("password_hash", .string, .required)
            .field("name", .string, .required)
            .field("role", role, .required, .sql(.default("free")))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users").delete()
        try await database.enum("user_role").delete()
    }
}
