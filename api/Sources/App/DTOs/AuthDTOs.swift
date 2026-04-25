import Vapor

struct RegisterRequest: Content, Sendable {
    let email: String
    let password: String
    let name: String
}

struct LoginRequest: Content, Sendable {
    let email: String
    let password: String
}

struct AuthResponse: Content, Sendable {
    let token: String
    let user: UserResponse
}

struct UserResponse: Content, Sendable {
    let id: UUID
    let email: String
    let name: String
    let role: UserRole

    init(_ user: User) throws {
        guard let id = user.id else {
            throw Abort(.internalServerError, reason: "user missing id")
        }
        self.id = id
        self.email = user.email
        self.name = user.name
        self.role = user.role
    }
}
