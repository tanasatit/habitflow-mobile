import Vapor
import Fluent

final class RevokedToken: Model, @unchecked Sendable {
    static let schema = "revoked_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "jti")
    var jti: String

    @Field(key: "expires_at")
    var expiresAt: Date

    init() {}

    init(jti: String, expiresAt: Date) {
        self.jti = jti
        self.expiresAt = expiresAt
    }
}
