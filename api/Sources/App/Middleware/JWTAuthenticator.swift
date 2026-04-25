import Vapor
import JWT

struct JWTAuthenticator: AsyncBearerAuthenticator {
    typealias User = UserPayload

    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        let payload = try await request.jwt.verify(bearer.token, as: UserPayload.self)
        request.auth.login(payload)
    }
}
