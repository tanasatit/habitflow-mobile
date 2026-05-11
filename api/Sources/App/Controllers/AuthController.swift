import Vapor
import Fluent
import JWT

struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
        auth.post("logout", use: logout)

        let protected = auth.grouped(JWTAuthenticator(), UserPayload.guardMiddleware())
        protected.get("me", use: me)
    }

    // MARK: POST /auth/register
    @Sendable
    func register(req: Request) async throws -> AuthResponse {
        let body = try req.content.decode(RegisterRequest.self)
        let email = body.email.lowercased()

        try Self.validateEmail(email)
        try Self.validatePassword(body.password)
        let name = body.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw Abort(.badRequest, reason: "name is required")
        }

        if try await User.query(on: req.db).filter(\.$email == email).first() != nil {
            throw Abort(.conflict, reason: "email already registered")
        }

        let hash = try await req.password.async.hash(body.password)
        let user = User(email: email, passwordHash: hash, name: name, role: .free)
        try await user.save(on: req.db)

        let token = try await Self.issueToken(for: user, on: req)
        return try AuthResponse(token: token, user: UserResponse(user))
    }

    // MARK: POST /auth/login
    @Sendable
    func login(req: Request) async throws -> AuthResponse {
        let body = try req.content.decode(LoginRequest.self)
        let email = body.email.lowercased()

        guard let user = try await User.query(on: req.db).filter(\.$email == email).first() else {
            throw Abort(.unauthorized, reason: "invalid credentials")
        }

        let ok = try await req.password.async.verify(body.password, created: user.passwordHash)
        guard ok else {
            throw Abort(.unauthorized, reason: "invalid credentials")
        }

        let token = try await Self.issueToken(for: user, on: req)
        return try AuthResponse(token: token, user: UserResponse(user))
    }

    // MARK: POST /auth/logout
    @Sendable
    func logout(req: Request) async throws -> HTTPStatus {
        guard let rawToken = req.headers.bearerAuthorization?.token,
              let payload = try? await req.jwt.verify(rawToken, as: UserPayload.self) else {
            return .noContent
        }
        let jtiValue = payload.jti.value
        let alreadyRevoked = try await RevokedToken.query(on: req.db)
            .filter(\RevokedToken.$jti, .equal, jtiValue)
            .first()
        guard alreadyRevoked == nil else { return .noContent }
        let revoked = RevokedToken(jti: jtiValue, expiresAt: payload.exp.value)
        try await revoked.save(on: req.db)
        return .noContent
    }

    // MARK: GET /auth/me
    @Sendable
    func me(req: Request) async throws -> UserResponse {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID,
              let user = try await User.find(userID, on: req.db) else {
            throw Abort(.unauthorized, reason: "user not found")
        }
        return try UserResponse(user)
    }

    // MARK: helpers
    private static func issueToken(for user: User, on req: Request) async throws -> String {
        guard let id = user.id else {
            throw Abort(.internalServerError, reason: "user missing id")
        }
        let payload = UserPayload(
            sub: .init(value: id.uuidString),
            email: user.email,
            role: user.role,
            exp: .init(value: Date().addingTimeInterval(60 * 60 * 24 * 30)),
            jti: .init(value: UUID().uuidString)
        )
        return try await req.jwt.sign(payload)
    }

    private static func validateEmail(_ email: String) throws {
        // Minimal sanity check; not RFC-perfect.
        guard email.contains("@"), email.contains("."), email.count >= 5 else {
            throw Abort(.badRequest, reason: "invalid email")
        }
    }

    private static func validatePassword(_ password: String) throws {
        guard password.count >= 8 else {
            throw Abort(.badRequest, reason: "password must be at least 8 characters")
        }
    }
}
