import Vapor

struct AdminMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let payload = try request.auth.require(UserPayload.self)
        guard payload.role == .admin else {
            throw Abort(.forbidden, reason: "admin access required")
        }
        return try await next.respond(to: request)
    }
}
