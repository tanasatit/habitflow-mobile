import XCTVapor
@testable import App

final class AuthControllerTests: XCTestCase {
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

    private func bearer(_ token: String) -> HTTPHeaders { ["Authorization": "Bearer \(token)"] }

    private func register(email: String = "auth@test.com") async throws -> String {
        var token = ""
        try await app.test(.POST, "auth/register",
            beforeRequest: { req in
                try req.content.encode(RegisterRequest(email: email, password: "password123", name: "Auth User"))
            },
            afterResponse: { res async throws in
                token = try res.content.decode(AuthResponse.self).token
            }
        )
        return token
    }

    func testLogoutInvalidatesToken() async throws {
        let token = try await register()

        // Token works before logout
        try await app.test(.GET, "auth/me", headers: bearer(token),
            afterResponse: { res async throws in XCTAssertEqual(res.status, .ok) }
        )

        // Logout
        try await app.test(.POST, "auth/logout", headers: bearer(token),
            afterResponse: { res async throws in XCTAssertEqual(res.status, .noContent) }
        )

        // Token is now rejected
        try await app.test(.GET, "auth/me", headers: bearer(token),
            afterResponse: { res async throws in XCTAssertEqual(res.status, .unauthorized) }
        )
    }

    func testLogoutWithNoTokenStillReturns204() async throws {
        try await app.test(.POST, "auth/logout",
            afterResponse: { res async throws in XCTAssertEqual(res.status, .noContent) }
        )
    }

    func testDoubleLogoutIsIdempotent() async throws {
        let token = try await register(email: "double@test.com")
        // First logout
        try await app.test(.POST, "auth/logout", headers: bearer(token),
            afterResponse: { res async throws in XCTAssertEqual(res.status, .noContent) }
        )
        // Second logout with same token must also return 204, not 500
        try await app.test(.POST, "auth/logout", headers: bearer(token),
            afterResponse: { res async throws in XCTAssertEqual(res.status, .noContent) }
        )
    }
}
