import Vapor
import JWT

struct JWTAuthenticator: AsyncBearerAuthenticator {
    typealias User = UserPayload

    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        let payload = try await request.jwt.verify(bearer.token, as: UserPayload.self)
        let jtiValue = payload.jti.value
        let revoked = try await RevokedToken.query(on: request.db)
            .filter(\RevokedToken.$jti, .equal, jtiValue)
            .first()
        if revoked != nil {
            throw Abort(.unauthorized, reason: "token has been revoked")
        }
        request.auth.login(payload)
    }
}
