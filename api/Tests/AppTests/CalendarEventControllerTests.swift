import XCTVapor
@testable import App

final class CalendarEventControllerTests: XCTestCase {
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

    private func register(email: String = "cal@test.com", name: String = "Cal User") async throws -> String {
        var token = ""
        try await app.test(.POST, "auth/register",
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

    private func bearer(_ token: String) -> HTTPHeaders { ["Authorization": "Bearer \(token)"] }

    private func makeEvent(
        token: String,
        title: String = "Team Standup",
        startAt: Date = Date().addingTimeInterval(3600),
        endAt: Date = Date().addingTimeInterval(5400)
    ) async throws -> CalendarEventResponse {
        var event: CalendarEventResponse?
        try await app.test(.POST, "calendar",
            headers: bearer(token),
            beforeRequest: { req in
                try req.content.encode(CreateCalendarEventRequest(
                    title: title, notes: nil,
                    startAt: startAt, endAt: endAt, allDay: nil
                ))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                event = try res.content.decode(CalendarEventResponse.self)
            }
        )
        return try XCTUnwrap(event)
    }

    func testCreateEventAcceptsISO8601DateStrings() async throws {
        let token = try await register()
        try await app.test(.POST, "calendar",
            beforeRequest: { req in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: """
                {"title":"ISO Test","startAt":"2026-05-10T07:00:00Z","endAt":"2026-05-10T07:30:00Z"}
                """)
                req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token)")
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                let event = try res.content.decode(CalendarEventResponse.self)
                // Verify the date round-trips — encoder produces ISO 8601, not a Double
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = TimeZone(identifier: "UTC")!
                let comps = cal.dateComponents([.year, .month, .day], from: event.startAt)
                XCTAssertEqual(comps.year, 2026)
                XCTAssertEqual(comps.month, 5)
                XCTAssertEqual(comps.day, 10)
            }
        )
    }

    // MARK: - Tests

    func testCreateEvent() async throws {
        let token = try await register()
        let start = Date().addingTimeInterval(3600)
        let end = Date().addingTimeInterval(5400)

        try await app.test(.POST, "calendar",
            headers: bearer(token),
            beforeRequest: { req in
                try req.content.encode(CreateCalendarEventRequest(
                    title: "  Morning Run  ", notes: "Easy pace",
                    startAt: start, endAt: end, allDay: false
                ))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                let body = try res.content.decode(CalendarEventResponse.self)
                XCTAssertEqual(body.title, "Morning Run")   // trimmed
                XCTAssertEqual(body.notes, "Easy pace")
                XCTAssertFalse(body.allDay)
            }
        )
    }

    func testCreateEventRejectsEndBeforeStart() async throws {
        let token = try await register()
        let now = Date()
        try await app.test(.POST, "calendar",
            headers: bearer(token),
            beforeRequest: { req in
                try req.content.encode(CreateCalendarEventRequest(
                    title: "Bad Event", notes: nil,
                    startAt: now.addingTimeInterval(3600), endAt: now, allDay: nil
                ))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        )
    }

    func testListEventsInRange() async throws {
        let token = try await register()
        let now = Date()
        // Inside range
        _ = try await makeEvent(token: token, startAt: now.addingTimeInterval(3600), endAt: now.addingTimeInterval(5400))
        // Outside range (far future)
        _ = try await makeEvent(token: token, startAt: now.addingTimeInterval(86400 * 10), endAt: now.addingTimeInterval(86400 * 10 + 1800))

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let start = iso.string(from: now)
        let end = iso.string(from: now.addingTimeInterval(86400))

        try await app.test(.GET, "calendar?start=\(start)&end=\(end)",
            headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let events = try res.content.decode([CalendarEventResponse].self)
                XCTAssertEqual(events.count, 1)
            }
        )
    }

    func testListEventsMissingParamsReturns400() async throws {
        let token = try await register()
        try await app.test(.GET, "calendar", headers: bearer(token),
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        )
    }

    func testUpdateEvent() async throws {
        let token = try await register()
        let event = try await makeEvent(token: token, title: "Old Title")

        try await app.test(.PATCH, "calendar/\(event.id)",
            headers: bearer(token),
            beforeRequest: { req in
                try req.content.encode(UpdateCalendarEventRequest(
                    title: "New Title", notes: nil, startAt: nil, endAt: nil, allDay: nil
                ))
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let body = try res.content.decode(CalendarEventResponse.self)
                XCTAssertEqual(body.title, "New Title")
            }
        )
    }

    func testDeleteEvent() async throws {
        let token = try await register()
        let event = try await makeEvent(token: token)

        try await app.test(.DELETE, "calendar/\(event.id)",
            headers: bearer(token),
            afterResponse: { res async throws in XCTAssertEqual(res.status, .noContent) }
        )
        try await app.test(.PATCH, "calendar/\(event.id)",
            headers: bearer(token),
            beforeRequest: { req in
                try req.content.encode(UpdateCalendarEventRequest(
                    title: "Ghost", notes: nil, startAt: nil, endAt: nil, allDay: nil
                ))
            },
            afterResponse: { res async throws in XCTAssertEqual(res.status, .notFound) }
        )
    }

    func testForbiddenForOtherUser() async throws {
        let token1 = try await register(email: "owner@test.com", name: "Owner")
        let token2 = try await register(email: "other@test.com", name: "Other")
        let event = try await makeEvent(token: token1)

        try await app.test(.PATCH, "calendar/\(event.id)",
            headers: bearer(token2),
            beforeRequest: { req in
                try req.content.encode(UpdateCalendarEventRequest(
                    title: "Hijack", notes: nil, startAt: nil, endAt: nil, allDay: nil
                ))
            },
            afterResponse: { res async throws in XCTAssertEqual(res.status, .forbidden) }
        )
    }

    func testRequiresAuth() async throws {
        try await app.test(.GET, "calendar?start=2026-01-01T00:00:00Z&end=2026-12-31T00:00:00Z",
            afterResponse: { res async throws in XCTAssertEqual(res.status, .unauthorized) }
        )
    }
}
