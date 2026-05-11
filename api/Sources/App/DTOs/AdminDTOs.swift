import Vapor

struct AdminUserResponse: Content, Sendable {
    let id: UUID
    let email: String
    let name: String
    let role: UserRole
    let createdAt: Date?

    init(_ user: User) throws {
        guard let id = user.id else { throw Abort(.internalServerError) }
        self.id = id
        self.email = user.email
        self.name = user.name
        self.role = user.role
        self.createdAt = user.createdAt
    }
}

struct UpdateRoleRequest: Content, Sendable {
    let role: String
}

struct SeedResponse: Content, Sendable {
    let message: String
    let userEmail: String
    let password: String
}
