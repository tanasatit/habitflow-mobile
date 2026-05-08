import Foundation

struct User: Codable, Sendable {
    let id: String
    let name: String
    let email: String
    let role: UserRole
}

enum UserRole: String, Codable, Sendable {
    case free, premium, admin
}

struct AuthResponse: Decodable, Sendable {
    let token: String
    let user: User
}
