import XCTVapor
@testable import App

final class AdminControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
        try await app.autoMigrate()
    }

    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
    }

    // MARK: - Helpers

    private func register(email: String, name: String, role: UserRole = .free) async throws -> (token: String, id: UUID) {
        var token = ""; var id = UUID()
        try await app.test(.POST, "auth/register",
            beforeRequest: { req in
                try req.content.encode(RegisterRequest(email: email, password: "password123", name: name))
            },
            afterResponse: { res async throws in
                let body = try res.content.decode(AuthResponse.self)
                token = body.token; id = body.user.id
            }
        )
        if role != .free {
            // Directly update role in DB for test setup
            guard let user = try await User.find(id, on: app.db) else { return (token, id) }
            user.role = role
            try await user.update(on: app.db)
            // Re-login to get a token with the new role
            try await app.test(.POST, "auth/login",
                beforeRequest: { req in
                    try req.content.encode(LoginRequest(email: email, password: "password123"))
                },
                afterResponse: { res async throws in
                    token = try res.content.decode(AuthResponse.self).token
                }
            )
        }
        return (token, id)
    }

    private func bearer(_ token: String) -> HTTPHeaders { ["Authorization": "Bearer \(token)"] }

    // MARK: - Tests

    func testListUsersRequiresAdmin() async throws {
        let (token, _) = try await register(email: "free@test.com", name: "Free")
        try await app.test(.GET, "admin/users", headers: bearer(token),
            afterResponse: { res async throws in XCTAssertEqual(res.status, .forbidden) }
        )
    }

    func testListUsers() async throws {
        let (adminToken, _) = try await register(email: "admin@test.com", name: "Admin", role: .admin)
        _ = try await register(email: "user1@test.com", name: "User1")

        try await app.test(.GET, "admin/users", headers: bearer(adminToken),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let users = try res.content.decode([AdminUserResponse].self)
                XCTAssertEqual(users.count, 2)
            }
        )
    }

    func testUpdateRole() async throws {
        let (adminToken, _) = try await register(email: "admin@test.com", name: "Admin", role: .admin)
        let (_, freeID) = try await register(email: "free@test.com", name: "Free")

        try await app.test(.PATCH, "admin/users/\(freeID)/role",
            headers: bearer(adminToken),
            beforeRequest: { req in
                try req.content.encode(UpdateRoleRequest(role: "premium"))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let body = try res.content.decode(AdminUserResponse.self)
                XCTAssertEqual(body.role, .premium)
            }
        )
    }

    func testUpdateRoleRejectsInvalidValue() async throws {
        let (adminToken, _) = try await register(email: "admin@test.com", name: "Admin", role: .admin)
        let (_, freeID) = try await register(email: "free@test.com", name: "Free")

        try await app.test(.PATCH, "admin/users/\(freeID)/role",
            headers: bearer(adminToken),
            beforeRequest: { req in
                try req.content.encode(UpdateRoleRequest(role: "superuser"))
            },
            afterResponse: { res async throws in XCTAssertEqual(res.status, .badRequest) }
        )
    }

    func testSeedIsIdempotent() async throws {
        let (adminToken, _) = try await register(email: "admin@test.com", name: "Admin", role: .admin)

        for _ in 0..<2 {
            try await app.test(.POST, "admin/seed", headers: bearer(adminToken),
                afterResponse: { res async throws in XCTAssertEqual(res.status, .ok) }
            )
        }

        // Habits should only exist once
        let demoUser: User? = try await User.query(on: app.db)
            .filter(\.$email, .equal, "demo@habitflow.app")
            .first()
        let demoUserID: UUID = try XCTUnwrap(demoUser).requireID()
        let count = try await Habit.query(on: app.db)
            .filter(\.$user.$id, .equal, demoUserID)
            .count()
        XCTAssertEqual(count, 4)
    }
}
