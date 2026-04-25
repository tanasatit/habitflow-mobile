import Vapor
import JWT

struct UserPayload: JWTPayload, Authenticatable, Sendable {
    var sub: SubjectClaim
    var email: String
    var role: UserRole
    var exp: ExpirationClaim

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.exp.verifyNotExpired()
    }

    var userID: UUID? {
        UUID(uuidString: sub.value)
    }
}
