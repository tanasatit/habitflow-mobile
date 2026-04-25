import Foundation

enum UserRole: String, Codable, Sendable, CaseIterable {
    case free
    case premium
    case admin
}
