import XCTVapor
@testable import App

final class HabitControllerTests: XCTestCase {

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

    private func register(
        email: String = "test@habits.com",
        name: String = "Test User"
    ) async throws -> String {
        var token = ""
        try await app.test(
            .POST, "auth/register",
            beforeRequest: { req in
                try req.content.encode(RegisterRequest(email: email, password: "password123", name: name))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                token = try res.content.decode(AuthResponse.self).token
            }
        )
        return token
    }

    private func bearer(_ token: String) -> HTTPHeaders {
        ["Authorization": "Bearer \(token)"]
    }

    private func makeHabit(token: String, name: String = "Morning Run") async throws -> HabitResponse {
        var habit: HabitResponse?
        try await app.test(
            .POST, "habits",
            headers: bearer(token),
            beforeRequest: { req in
                try req.content.encode(CreateHabitRequest(
                    name: name, category: "fitness", frequency: "daily",
                    targetTime: nil, description: nil
                ))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                habit = try res.content.decode(HabitResponse.self)
            }
        )
        return try XCTUnwrap(habit)
    }

    private func logHabit(id: UUID, token: String) async throws {
        try await app.test(
            .POST, "habits/\(id)/log",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
            }
        )
    }

    // MARK: - Habit CRUD

    func testCreateHabit() async throws {
        let token = try await register()
        try await app.test(
            .POST, "habits",
            headers: bearer(token),
            beforeRequest: { req in
                try req.content.encode(CreateHabitRequest(
                    name: "  Read  ", category: "learning", frequency: "daily",
                    targetTime: "08:00", description: "10 pages a day"
                ))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                let body = try res.content.decode(HabitResponse.self)
                XCTAssertEqual(body.name, "Read")   // trimmed
                XCTAssertEqual(body.frequency, "daily")
                XCTAssertEqual(body.category, "learning")
                XCTAssertTrue(body.isActive)
            }
        )
    }

    func testCreateHabitRejectsEmptyName() async throws {
        let token = try await register()
        try await app.test(
            .POST, "habits",
            headers: bearer(token),
            beforeRequest: { req in
                try req.content.encode(CreateHabitRequest(
                    name: "   ", category: nil, frequency: nil, targetTime: nil, description: nil
                ))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        )
    }

    func testListHabitsReturnsOnlyOwnHabits() async throws {
        let token1 = try await register(email: "a@test.com", name: "A")
        let token2 = try await register(email: "b@test.com", name: "B")

        _ = try await makeHabit(token: token1, name: "A1")
        _ = try await makeHabit(token: token1, name: "A2")
        _ = try await makeHabit(token: token2, name: "B1")

        try await app.test(
            .GET, "habits",
            headers: bearer(token1),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let habits = try res.content.decode([HabitResponse].self)
                XCTAssertEqual(habits.count, 2)
                XCTAssertTrue(habits.allSatisfy { $0.name.hasPrefix("A") })
            }
        )
    }

    func testShowHabit() async throws {
        let token = try await register()
        let created = try await makeHabit(token: token)

        try await app.test(
            .GET, "habits/\(created.id)",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let body = try res.content.decode(HabitResponse.self)
                XCTAssertEqual(body.id, created.id)
            }
        )
    }

    func testUpdateHabit() async throws {
        let token = try await register()
        let created = try await makeHabit(token: token, name: "Old Name")

        try await app.test(
            .PUT, "habits/\(created.id)",
            headers: bearer(token),
            beforeRequest: { req in
                try req.content.encode(UpdateHabitRequest(
                    name: "New Name", category: nil, targetTime: nil, description: nil, isActive: nil
                ))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let body = try res.content.decode(HabitResponse.self)
                XCTAssertEqual(body.name, "New Name")
            }
        )
    }

    func testDeleteHabit() async throws {
        let token = try await register()
        let created = try await makeHabit(token: token)

        try await app.test(
            .DELETE, "habits/\(created.id)",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .noContent)
            }
        )

        try await app.test(
            .GET, "habits/\(created.id)",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            }
        )
    }

    // MARK: - Ownership enforcement

    func testShowForbiddenForOtherUser() async throws {
        let token1 = try await register(email: "owner@test.com", name: "Owner")
        let token2 = try await register(email: "other@test.com", name: "Other")
        let habit = try await makeHabit(token: token1)

        try await app.test(
            .GET, "habits/\(habit.id)",
            headers: bearer(token2),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .forbidden)
            }
        )
    }

    func testDeleteForbiddenForOtherUser() async throws {
        let token1 = try await register(email: "owner@test.com", name: "Owner")
        let token2 = try await register(email: "other@test.com", name: "Other")
        let habit = try await makeHabit(token: token1)

        try await app.test(
            .DELETE, "habits/\(habit.id)",
            headers: bearer(token2),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .forbidden)
            }
        )
    }

    func testUpdateForbiddenForOtherUser() async throws {
        let token1 = try await register(email: "owner@test.com", name: "Owner")
        let token2 = try await register(email: "other@test.com", name: "Other")
        let habit = try await makeHabit(token: token1)

        try await app.test(
            .PUT, "habits/\(habit.id)",
            headers: bearer(token2),
            beforeRequest: { req in
                try req.content.encode(UpdateHabitRequest(
                    name: "Hijack", category: nil, targetTime: nil, description: nil, isActive: nil
                ))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .forbidden)
            }
        )
    }

    func testLogForbiddenForOtherUser() async throws {
        let token1 = try await register(email: "owner@test.com", name: "Owner")
        let token2 = try await register(email: "other@test.com", name: "Other")
        let habit = try await makeHabit(token: token1)

        try await app.test(
            .POST, "habits/\(habit.id)/log",
            headers: bearer(token2),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .forbidden)
            }
        )
    }

    func testStatsForbiddenForOtherUser() async throws {
        let token1 = try await register(email: "owner@test.com", name: "Owner")
        let token2 = try await register(email: "other@test.com", name: "Other")
        let habit = try await makeHabit(token: token1)

        try await app.test(
            .GET, "habits/\(habit.id)/stats",
            headers: bearer(token2),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .forbidden)
            }
        )
    }

    // MARK: - Logging

    func testLogHabit() async throws {
        let token = try await register()
        let habit = try await makeHabit(token: token)

        try await app.test(
            .POST, "habits/\(habit.id)/log",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                let body = try res.content.decode(HabitLogResponse.self)
                XCTAssertEqual(body.habitID, habit.id)
            }
        )
    }

    func testDuplicateLogIsRejected() async throws {
        let token = try await register()
        let habit = try await makeHabit(token: token)
        try await logHabit(id: habit.id, token: token)

        // Second log on the same day must return 409.
        try await app.test(
            .POST, "habits/\(habit.id)/log",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .conflict)
            }
        )
    }

    func testUnlogHabit() async throws {
        let token = try await register()
        let habit = try await makeHabit(token: token)
        try await logHabit(id: habit.id, token: token)

        try await app.test(
            .DELETE, "habits/\(habit.id)/log",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .noContent)
            }
        )
    }

    func testUnlogFailsWhenNothingLogged() async throws {
        let token = try await register()
        let habit = try await makeHabit(token: token)

        try await app.test(
            .DELETE, "habits/\(habit.id)/log",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            }
        )
    }

    // MARK: - Stats

    func testStatsAfterOneLog() async throws {
        let token = try await register()
        let habit = try await makeHabit(token: token)
        try await logHabit(id: habit.id, token: token)

        try await app.test(
            .GET, "habits/\(habit.id)/stats",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let stats = try res.content.decode(HabitStatsResponse.self)
                XCTAssertEqual(stats.habitID, habit.id)
                XCTAssertEqual(stats.currentStreak, 1)
                XCTAssertEqual(stats.longestStreak, 1)
                XCTAssertEqual(stats.weekGrid.count, 7)
                XCTAssertTrue(stats.weekGrid[6])  // today = last slot
                XCTAssertGreaterThan(stats.completionRate, 0)
            }
        )
    }

    func testStatsZeroWhenNoLogs() async throws {
        let token = try await register()
        let habit = try await makeHabit(token: token)

        try await app.test(
            .GET, "habits/\(habit.id)/stats",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let stats = try res.content.decode(HabitStatsResponse.self)
                XCTAssertEqual(stats.currentStreak, 0)
                XCTAssertEqual(stats.longestStreak, 0)
                XCTAssertEqual(stats.completionRate, 0.0)
                XCTAssertEqual(stats.weekGrid, Array(repeating: false, count: 7))
            }
        )
    }

    // MARK: - Dashboard

    func testDashboardReflectsLoggedHabit() async throws {
        let token = try await register()
        let habit = try await makeHabit(token: token)
        try await logHabit(id: habit.id, token: token)

        try await app.test(
            .GET, "dashboard",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let dash = try res.content.decode(DashboardResponse.self)
                XCTAssertEqual(dash.habitsSummary.total, 1)
                XCTAssertEqual(dash.habitsSummary.completedToday, 1)
                XCTAssertEqual(dash.overallStreak, 1)
                XCTAssertEqual(dash.todayHabits.count, 1)
                XCTAssertTrue(dash.todayHabits[0].completedToday)
            }
        )
    }

    func testDashboardEmptyForNewUser() async throws {
        let token = try await register()

        try await app.test(
            .GET, "dashboard",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let dash = try res.content.decode(DashboardResponse.self)
                XCTAssertEqual(dash.habitsSummary.total, 0)
                XCTAssertEqual(dash.habitsSummary.completedToday, 0)
                XCTAssertEqual(dash.overallStreak, 0)
                XCTAssertTrue(dash.todayHabits.isEmpty)
            }
        )
    }

    // MARK: - Frequency validation

    func testCreateHabitRejectsInvalidFrequency() async throws {
        let token = try await register()
        try await app.test(.POST, "habits",
            headers: bearer(token),
            beforeRequest: { req in
                try req.content.encode(CreateHabitRequest(
                    name: "Test", category: nil, frequency: "sometimes",
                    targetTime: nil, description: nil
                ))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        )
    }

    func testUpdateHabitRejectsInvalidFrequency() async throws {
        let token = try await register()
        let habit = try await makeHabit(token: token)
        try await app.test(.PUT, "habits/\(habit.id)",
            headers: bearer(token),
            beforeRequest: { req in
                try req.content.encode(UpdateHabitRequest(
                    name: nil, category: nil, targetTime: nil,
                    description: nil, isActive: nil, frequency: "never"
                ))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        )
    }

    // MARK: - Auth guard

    func testEndpointsRequireToken() async throws {
        try await app.test(.GET, "habits", afterResponse: { res async in
            XCTAssertEqual(res.status, .unauthorized)
        })
        try await app.test(.GET, "dashboard", afterResponse: { res async in
            XCTAssertEqual(res.status, .unauthorized)
        })
    }
}
