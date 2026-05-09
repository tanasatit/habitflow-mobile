import Fluent

struct AddRevokedTokens: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("revoked_tokens")
            .id()
            .field("jti", .string, .required)
            .field("expires_at", .datetime, .required)
            .unique(on: "jti")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("revoked_tokens").delete()
    }
}
