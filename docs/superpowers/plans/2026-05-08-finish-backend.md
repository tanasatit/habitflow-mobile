# HabitFlow Backend — Finish Sprint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship CalendarEvent CRUD, AI Coach (Gemini function-calling), Admin (list + role update), and a demo seed endpoint — everything needed for the Day 7 demo checklist.

**Architecture:** Four independent controllers following the existing RouteCollection pattern. AI Coach is the only stateful piece: a two-turn Gemini conversation (user message → optional function call → final reply) handled entirely in AICoachService. All new types are Swift 6 `Sendable`; models are `@unchecked Sendable` like existing models.

**Tech Stack:** Vapor 4, Fluent + FluentPostgresDriver, XCTVapor, Gemini REST API (gemini-2.0-flash), Swift 6 strict concurrency.

---

## File Map

**Create:**
```
api/Sources/App/Models/CalendarEvent.swift
api/Sources/App/Migrations/CreateCalendarEvent.swift
api/Sources/App/DTOs/CalendarEventDTOs.swift
api/Sources/App/Controllers/CalendarEventController.swift
api/Sources/App/DTOs/AICoachDTOs.swift
api/Sources/App/Services/GeminiClient.swift
api/Sources/App/Services/AICoachService.swift
api/Sources/App/Controllers/AICoachController.swift
api/Sources/App/Middleware/AdminMiddleware.swift
api/Sources/App/DTOs/AdminDTOs.swift
api/Sources/App/Controllers/AdminController.swift
api/Tests/AppTests/CalendarEventControllerTests.swift
api/Tests/AppTests/AdminControllerTests.swift
```

**Modify:**
```
api/Sources/App/configure.swift   — register CreateCalendarEvent migration
api/Sources/App/routes.swift      — register 3 new controllers
api/.env.example                  — add GEMINI_API_KEY
```

---

## Task 1: CalendarEvent — Model + Migration

**Files:**
- Create: `api/Sources/App/Models/CalendarEvent.swift`
- Create: `api/Sources/App/Migrations/CreateCalendarEvent.swift`

- [ ] **Step 1: Create the model**

`api/Sources/App/Models/CalendarEvent.swift`:
```swift
import Vapor
import Fluent

final class CalendarEvent: Model, @unchecked Sendable {
    static let schema = "calendar_events"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "title")
    var title: String

    @OptionalField(key: "notes")
    var notes: String?

    @Field(key: "start_at")
    var startAt: Date

    @Field(key: "end_at")
    var endAt: Date

    @Field(key: "all_day")
    var allDay: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        title: String,
        notes: String? = nil,
        startAt: Date,
        endAt: Date,
        allDay: Bool = false
    ) {
        self.id = id
        self.$user.id = userID
        self.title = title
        self.notes = notes
        self.startAt = startAt
        self.endAt = endAt
        self.allDay = allDay
    }
}
```

- [ ] **Step 2: Create the migration**

`api/Sources/App/Migrations/CreateCalendarEvent.swift`:
```swift
import Fluent

struct CreateCalendarEvent: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("calendar_events")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("title", .string, .required)
            .field("notes", .string)
            .field("start_at", .datetime, .required)
            .field("end_at", .datetime, .required)
            .field("all_day", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("calendar_events").delete()
    }
}
```

- [ ] **Step 3: Register migration in configure.swift**

Add after `app.migrations.add(AddUniqueHabitLogPerDay())`:
```swift
app.migrations.add(CreateCalendarEvent())
```

- [ ] **Step 4: Verify build**

```bash
cd api && swift build
```
Expected: `Build complete!`

---

## Task 2: CalendarEvent — DTOs + Controller

**Files:**
- Create: `api/Sources/App/DTOs/CalendarEventDTOs.swift`
- Create: `api/Sources/App/Controllers/CalendarEventController.swift`
- Modify: `api/Sources/App/routes.swift`

- [ ] **Step 1: Write DTOs**

`api/Sources/App/DTOs/CalendarEventDTOs.swift`:
```swift
import Vapor

struct CreateCalendarEventRequest: Content, Sendable {
    let title: String
    let notes: String?
    let startAt: Date
    let endAt: Date
    let allDay: Bool?
}

struct UpdateCalendarEventRequest: Content, Sendable {
    let title: String?
    let notes: String?
    let startAt: Date?
    let endAt: Date?
    let allDay: Bool?
}

struct CalendarEventResponse: Content, Sendable {
    let id: UUID
    let userID: UUID
    let title: String
    let notes: String?
    let startAt: Date
    let endAt: Date
    let allDay: Bool
    let createdAt: Date?
    let updatedAt: Date?

    init(_ event: CalendarEvent) throws {
        guard let id = event.id else { throw Abort(.internalServerError) }
        self.id = id
        self.userID = event.$user.id
        self.title = event.title
        self.notes = event.notes
        self.startAt = event.startAt
        self.endAt = event.endAt
        self.allDay = event.allDay
        self.createdAt = event.createdAt
        self.updatedAt = event.updatedAt
    }
}
```

- [ ] **Step 2: Write the controller**

`api/Sources/App/Controllers/CalendarEventController.swift`:
```swift
import Vapor
import Fluent

struct CalendarEventController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let protected = routes
            .grouped("calendar")
            .grouped(JWTAuthenticator(), UserPayload.guardMiddleware())

        protected.get(use: index)
        protected.post(use: create)
        protected.patch(":eventID", use: update)
        protected.delete(":eventID", use: delete)
    }

    // MARK: GET /calendar?start=&end=
    @Sendable
    func index(req: Request) async throws -> [CalendarEventResponse] {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        guard let startStr = req.query[String.self, at: "start"],
              let endStr = req.query[String.self, at: "end"] else {
            throw Abort(.badRequest, reason: "start and end query parameters are required (ISO8601, e.g. 2026-05-08T00:00:00Z)")
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let start = iso.date(from: startStr) ?? isoFrac.date(from: startStr) else {
            throw Abort(.badRequest, reason: "invalid start — use ISO8601 e.g. 2026-05-08T00:00:00Z")
        }
        guard let end = iso.date(from: endStr) ?? isoFrac.date(from: endStr) else {
            throw Abort(.badRequest, reason: "invalid end — use ISO8601 e.g. 2026-05-08T23:59:59Z")
        }
        guard end > start else {
            throw Abort(.badRequest, reason: "end must be after start")
        }

        let events = try await CalendarEvent.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$startAt >= start)
            .filter(\.$startAt < end)
            .sort(\.$startAt, .ascending)
            .all()

        return try events.map { try CalendarEventResponse($0) }
    }

    // MARK: POST /calendar
    @Sendable
    func create(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let body = try req.content.decode(CreateCalendarEventRequest.self)
        let title = body.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw Abort(.badRequest, reason: "title is required") }
        guard body.endAt > body.startAt else {
            throw Abort(.badRequest, reason: "endAt must be after startAt")
        }

        let event = CalendarEvent(
            userID: userID,
            title: title,
            notes: body.notes,
            startAt: body.startAt,
            endAt: body.endAt,
            allDay: body.allDay ?? false
        )
        try await event.save(on: req.db)
        return try await CalendarEventResponse(event).encodeResponse(status: .created, for: req)
    }

    // MARK: PATCH /calendar/:eventID
    @Sendable
    func update(req: Request) async throws -> CalendarEventResponse {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let event = try await findEventOrAbort(req: req, userID: userID)
        let body = try req.content.decode(UpdateCalendarEventRequest.self)

        if let title = body.title {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw Abort(.badRequest, reason: "title cannot be empty") }
            event.title = trimmed
        }
        if let notes = body.notes { event.notes = notes }
        if let startAt = body.startAt { event.startAt = startAt }
        if let endAt = body.endAt { event.endAt = endAt }
        if let allDay = body.allDay { event.allDay = allDay }

        guard event.endAt > event.startAt else {
            throw Abort(.badRequest, reason: "endAt must be after startAt")
        }

        try await event.update(on: req.db)
        return try CalendarEventResponse(event)
    }

    // MARK: DELETE /calendar/:eventID
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let event = try await findEventOrAbort(req: req, userID: userID)
        try await event.delete(on: req.db)
        return .noContent
    }

    // MARK: - Private
    private func findEventOrAbort(req: Request, userID: UUID) async throws -> CalendarEvent {
        guard let eventID = req.parameters.get("eventID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "invalid event ID")
        }
        guard let event = try await CalendarEvent.find(eventID, on: req.db) else {
            throw Abort(.notFound)
        }
        guard event.$user.id == userID else {
            throw Abort(.forbidden, reason: "not your event")
        }
        return event
    }
}
```

- [ ] **Step 3: Register controller in routes.swift**

Add to `routes.swift`:
```swift
try app.register(collection: CalendarEventController())
```

- [ ] **Step 4: Build**

```bash
swift build
```
Expected: `Build complete!`

---

## Task 3: CalendarEvent — Tests

**Files:**
- Create: `api/Tests/AppTests/CalendarEventControllerTests.swift`

- [ ] **Step 1: Write tests**

`api/Tests/AppTests/CalendarEventControllerTests.swift`:
```swift
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
```

- [ ] **Step 2: Run tests**

```bash
docker compose up -d && swift test --filter AppTests/CalendarEventControllerTests
```
Expected: all 7 tests pass.

- [ ] **Step 3: Commit**

```bash
git add api/Sources/App/Models/CalendarEvent.swift \
        api/Sources/App/Migrations/CreateCalendarEvent.swift \
        api/Sources/App/DTOs/CalendarEventDTOs.swift \
        api/Sources/App/Controllers/CalendarEventController.swift \
        api/Sources/App/configure.swift \
        api/Sources/App/routes.swift \
        api/Tests/AppTests/CalendarEventControllerTests.swift
git commit -m "feat: add CalendarEvent CRUD — GET/POST/PATCH/DELETE /calendar"
```

---

## Task 4: AI Coach — DTOs + GeminiClient

**Files:**
- Create: `api/Sources/App/DTOs/AICoachDTOs.swift`
- Create: `api/Sources/App/Services/GeminiClient.swift`
- Modify: `api/.env.example`

- [ ] **Step 1: Write AI Coach DTOs**

`api/Sources/App/DTOs/AICoachDTOs.swift`:
```swift
import Vapor

// MARK: - Chat API (client-facing)

struct ChatRequest: Content, Sendable {
    let message: String
}

struct ChatResponse: Content, Sendable {
    let reply: String
    let calendarUpdated: Bool
}

// MARK: - Gemini wire types

struct GeminiGenerateRequest: Encodable, Sendable {
    let tools: [GeminiTool]
    var contents: [GeminiContent]
}

struct GeminiGenerateResponse: Decodable, Sendable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Decodable, Sendable {
    let content: GeminiContent
}

struct GeminiContent: Codable, Sendable {
    let role: String
    let parts: [GeminiPart]
}

struct GeminiPart: Codable, Sendable {
    let text: String?
    let functionCall: GeminiFunctionCall?
    let functionResponse: GeminiFunctionResponse?

    init(text: String) {
        self.text = text; self.functionCall = nil; self.functionResponse = nil
    }
    init(functionResponse: GeminiFunctionResponse) {
        self.text = nil; self.functionCall = nil; self.functionResponse = functionResponse
    }

    private enum CodingKeys: String, CodingKey {
        case text, functionCall, functionResponse
    }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(functionCall, forKey: .functionCall)
        try c.encodeIfPresent(functionResponse, forKey: .functionResponse)
    }
}

struct GeminiFunctionCall: Codable, Sendable {
    let name: String
    let args: GeminiFunctionCallArgs
}

struct GeminiFunctionCallArgs: Codable, Sendable {
    let events: [GeminiCalendarEventArg]?

    private enum CodingKeys: String, CodingKey { case events }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(events, forKey: .events)
    }
}

struct GeminiCalendarEventArg: Codable, Sendable {
    let title: String
    let startAt: String
    let endAt: String
    let notes: String?

    private enum CodingKeys: String, CodingKey { case title, startAt, endAt, notes }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(startAt, forKey: .startAt)
        try c.encode(endAt, forKey: .endAt)
        try c.encodeIfPresent(notes, forKey: .notes)
    }
}

struct GeminiFunctionResponse: Codable, Sendable {
    let name: String
    let response: [String: String]
}

struct GeminiTool: Encodable, Sendable {
    let functionDeclarations: [GeminiFunctionDeclaration]
}

struct GeminiFunctionDeclaration: Encodable, Sendable {
    let name: String
    let description: String
    let parameters: GeminiParameters
}

struct GeminiParameters: Encodable, Sendable {
    let type: String
    let properties: [String: GeminiProperty]
    let required: [String]
}

struct GeminiProperty: Encodable, Sendable {
    let type: String
    let description: String?
    let items: GeminiItems?

    init(type: String, description: String? = nil, items: GeminiItems? = nil) {
        self.type = type; self.description = description; self.items = items
    }

    private enum CodingKeys: String, CodingKey { case type, description, items }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(items, forKey: .items)
    }
}

struct GeminiItems: Encodable, Sendable {
    let type: String
    let properties: [String: GeminiProperty]?
    let required: [String]?

    private enum CodingKeys: String, CodingKey { case type, properties, required }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(properties, forKey: .properties)
        try c.encodeIfPresent(required, forKey: .required)
    }
}
```

- [ ] **Step 2: Write GeminiClient**

`api/Sources/App/Services/GeminiClient.swift`:
```swift
import Vapor

struct GeminiClient: Sendable {
    let apiKey: String

    func generateContent(_ body: GeminiGenerateRequest, on req: Request) async throws -> GeminiGenerateResponse {
        let url = URI(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)")

        let response = try await req.client.post(url) { clientReq in
            clientReq.headers.contentType = .json
            try clientReq.content.encode(body)
        }

        guard response.status == .ok else {
            let reason = (try? response.content.decode([String: String].self))?["error"] ?? "\(response.status)"
            throw Abort(.badGateway, reason: "Gemini error: \(reason)")
        }

        return try response.content.decode(GeminiGenerateResponse.self)
    }
}
```

- [ ] **Step 3: Add GEMINI_API_KEY to .env.example**

Add this line to `api/.env.example`:
```
GEMINI_API_KEY=your-gemini-api-key-here
```

- [ ] **Step 4: Build**

```bash
swift build
```
Expected: `Build complete!`

---

## Task 5: AI Coach — Service + Controller

**Files:**
- Create: `api/Sources/App/Services/AICoachService.swift`
- Create: `api/Sources/App/Controllers/AICoachController.swift`
- Modify: `api/Sources/App/routes.swift`

- [ ] **Step 1: Write AICoachService**

`api/Sources/App/Services/AICoachService.swift`:
```swift
import Vapor
import Fluent

struct AICoachService: Sendable {
    private let gemini: GeminiClient

    init(gemini: GeminiClient) {
        self.gemini = gemini
    }

    func chat(message: String, userID: UUID, req: Request) async throws -> (reply: String, calendarUpdated: Bool) {
        var contents: [GeminiContent] = [
            GeminiContent(role: "user", parts: [GeminiPart(text: message)])
        ]
        let request = GeminiGenerateRequest(tools: [buildTools()], contents: contents)

        let response1 = try await gemini.generateContent(request, on: req)
        guard let candidate = response1.candidates.first else {
            throw Abort(.badGateway, reason: "AI returned no response")
        }

        if let functionCall = candidate.content.parts.first?.functionCall {
            let (funcResponse, calendarUpdated) = try await executeFunction(functionCall, userID: userID, req: req)

            contents.append(candidate.content)
            contents.append(GeminiContent(role: "user", parts: [GeminiPart(functionResponse: funcResponse)]))

            var request2 = request
            request2.contents = contents
            let response2 = try await gemini.generateContent(request2, on: req)

            guard let text = response2.candidates.first?.content.parts.first?.text else {
                throw Abort(.badGateway, reason: "AI returned no final response")
            }
            return (reply: text, calendarUpdated: calendarUpdated)
        }

        guard let text = candidate.content.parts.first?.text else {
            throw Abort(.badGateway, reason: "AI returned no response")
        }
        return (reply: text, calendarUpdated: false)
    }

    // MARK: - Function execution

    private func executeFunction(
        _ call: GeminiFunctionCall,
        userID: UUID,
        req: Request
    ) async throws -> (GeminiFunctionResponse, Bool) {
        switch call.name {
        case "get_user_habits":
            let habits = try await Habit.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$isActive == true)
                .all()
            let summary = habits.isEmpty
                ? "No active habits found."
                : habits.map { "\($0.name) (\($0.category ?? "general"), \($0.frequency))" }.joined(separator: "; ")
            return (GeminiFunctionResponse(name: "get_user_habits", response: ["result": summary]), false)

        case "write_calendar":
            guard let eventArgs = call.args.events, !eventArgs.isEmpty else {
                return (GeminiFunctionResponse(name: "write_calendar", response: ["result": "No events provided."]), false)
            }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            var created = 0
            for arg in eventArgs {
                guard let start = iso.date(from: arg.startAt),
                      let end = iso.date(from: arg.endAt),
                      end > start else { continue }
                let event = CalendarEvent(userID: userID, title: arg.title, notes: arg.notes, startAt: start, endAt: end)
                try await event.save(on: req.db)
                created += 1
            }
            let result = created == 0
                ? "No valid events created."
                : "Created \(created) calendar event\(created == 1 ? "" : "s")."
            return (GeminiFunctionResponse(name: "write_calendar", response: ["result": result]), created > 0)

        default:
            return (GeminiFunctionResponse(name: call.name, response: ["result": "Unknown function."]), false)
        }
    }

    // MARK: - Tool declarations

    private func buildTools() -> GeminiTool {
        GeminiTool(functionDeclarations: [
            GeminiFunctionDeclaration(
                name: "get_user_habits",
                description: "Returns the user's active habits including name, category, and frequency.",
                parameters: GeminiParameters(type: "OBJECT", properties: [:], required: [])
            ),
            GeminiFunctionDeclaration(
                name: "write_calendar",
                description: "Creates calendar events for the user. Use ISO8601 UTC format for dates, e.g. 2026-05-11T07:00:00Z.",
                parameters: GeminiParameters(
                    type: "OBJECT",
                    properties: [
                        "events": GeminiProperty(
                            type: "ARRAY",
                            description: "Events to create",
                            items: GeminiItems(
                                type: "OBJECT",
                                properties: [
                                    "title":   GeminiProperty(type: "STRING", description: "Event title"),
                                    "startAt": GeminiProperty(type: "STRING", description: "ISO8601 start time"),
                                    "endAt":   GeminiProperty(type: "STRING", description: "ISO8601 end time"),
                                    "notes":   GeminiProperty(type: "STRING", description: "Optional notes")
                                ],
                                required: ["title", "startAt", "endAt"]
                            )
                        )
                    ],
                    required: ["events"]
                )
            )
        ])
    }
}
```

- [ ] **Step 2: Write AICoachController**

`api/Sources/App/Controllers/AICoachController.swift`:
```swift
import Vapor

struct AICoachController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let protected = routes
            .grouped("ai")
            .grouped(JWTAuthenticator(), UserPayload.guardMiddleware())
        protected.post("chat", use: chat)
    }

    @Sendable
    func chat(req: Request) async throws -> ChatResponse {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let body = try req.content.decode(ChatRequest.self)
        guard !body.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "message is required")
        }

        guard let apiKey = Environment.get("GEMINI_API_KEY"), !apiKey.isEmpty else {
            throw Abort(.serviceUnavailable, reason: "AI Coach is not configured (GEMINI_API_KEY missing)")
        }

        let service = AICoachService(gemini: GeminiClient(apiKey: apiKey))
        let (reply, calendarUpdated) = try await service.chat(message: body.message, userID: userID, req: req)
        return ChatResponse(reply: reply, calendarUpdated: calendarUpdated)
    }
}
```

- [ ] **Step 3: Register controller in routes.swift**

Add to `routes.swift`:
```swift
try app.register(collection: AICoachController())
```

- [ ] **Step 4: Build**

```bash
swift build
```
Expected: `Build complete!`

- [ ] **Step 5: Smoke test (requires GEMINI_API_KEY in .env)**

```bash
# Get a token first
TOKEN=$(curl -s -X POST http://127.0.0.1:8080/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"ai@test.com","password":"password123","name":"AI Tester"}' | jq -r '.token')

curl -X POST http://127.0.0.1:8080/ai/chat \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"message":"What habits do I have?"}'
```
Expected: `{"reply":"...","calendarUpdated":false}`

- [ ] **Step 6: Commit**

```bash
git add api/Sources/App/DTOs/AICoachDTOs.swift \
        api/Sources/App/Services/GeminiClient.swift \
        api/Sources/App/Services/AICoachService.swift \
        api/Sources/App/Controllers/AICoachController.swift \
        api/Sources/App/routes.swift \
        api/.env.example
git commit -m "feat: add AI Coach — POST /ai/chat with Gemini function-calling"
```

---

## Task 6: Admin — Middleware + Controller

**Files:**
- Create: `api/Sources/App/Middleware/AdminMiddleware.swift`
- Create: `api/Sources/App/DTOs/AdminDTOs.swift`
- Create: `api/Sources/App/Controllers/AdminController.swift`
- Modify: `api/Sources/App/routes.swift`

- [ ] **Step 1: Write AdminMiddleware**

`api/Sources/App/Middleware/AdminMiddleware.swift`:
```swift
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
```

- [ ] **Step 2: Write Admin DTOs**

`api/Sources/App/DTOs/AdminDTOs.swift`:
```swift
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
```

- [ ] **Step 3: Write AdminController**

`api/Sources/App/Controllers/AdminController.swift`:
```swift
import Vapor
import Fluent

struct AdminController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let admin = routes
            .grouped("admin")
            .grouped(JWTAuthenticator(), UserPayload.guardMiddleware(), AdminMiddleware())

        admin.get("users", use: listUsers)
        admin.patch("users", ":userID", "role", use: updateRole)
        admin.post("seed", use: seed)
    }

    // MARK: GET /admin/users
    @Sendable
    func listUsers(req: Request) async throws -> [AdminUserResponse] {
        let users = try await User.query(on: req.db)
            .sort(\.$createdAt, .ascending)
            .all()
        return try users.map { try AdminUserResponse($0) }
    }

    // MARK: PATCH /admin/users/:userID/role
    @Sendable
    func updateRole(req: Request) async throws -> AdminUserResponse {
        guard let userID = req.parameters.get("userID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "invalid user ID")
        }
        guard let user = try await User.find(userID, on: req.db) else {
            throw Abort(.notFound, reason: "user not found")
        }
        let body = try req.content.decode(UpdateRoleRequest.self)
        guard let newRole = UserRole(rawValue: body.role) else {
            throw Abort(.badRequest, reason: "invalid role — valid values: free, premium, admin")
        }
        user.role = newRole
        try await user.update(on: req.db)
        return try AdminUserResponse(user)
    }

    // MARK: POST /admin/seed
    @Sendable
    func seed(req: Request) async throws -> SeedResponse {
        let demoEmail = "demo@habitflow.app"
        let demoPassword = "Demo1234!"

        let demoUser: User
        if let existing = try await User.query(on: req.db).filter(\.$email == demoEmail).first() {
            demoUser = existing
        } else {
            let hash = try await req.password.async.hash(demoPassword)
            let user = User(email: demoEmail, passwordHash: hash, name: "Demo User", role: .free)
            try await user.save(on: req.db)
            demoUser = user
        }
        guard let userID = demoUser.id else { throw Abort(.internalServerError) }

        let existingHabits = try await Habit.query(on: req.db).filter(\.$user.$id == userID).count()
        guard existingHabits == 0 else {
            return SeedResponse(message: "Already seeded", userEmail: demoEmail, password: demoPassword)
        }

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!

        let habitDefs: [(String, String)] = [
            ("Morning Run", "fitness"),
            ("Read 10 Pages", "learning"),
            ("Meditate", "wellness"),
            ("Drink Water", "health")
        ]

        for (name, category) in habitDefs {
            let habit = Habit(userID: userID, name: name, category: category, frequency: "daily", targetTime: nil, description: nil)
            try await habit.save(on: req.db)
            guard let habitID = habit.id else { continue }

            for dayOffset in 0..<8 {
                var comps = utc.dateComponents([.year, .month, .day], from: Date())
                comps.hour = 8; comps.minute = 0; comps.second = 0
                comps.timeZone = TimeZone(identifier: "UTC")
                let baseDate = utc.date(from: comps)!
                let logDate = utc.date(byAdding: .day, value: -dayOffset, to: baseDate)!
                let log = HabitLog(habitID: habitID, userID: userID, completedAt: logDate)
                try await log.save(on: req.db)
            }
        }

        for date in upcomingMWFDates(count: 3, after: Date(), calendar: utc) {
            let end = utc.date(byAdding: .minute, value: 30, to: date)!
            let event = CalendarEvent(userID: userID, title: "Morning Run", notes: "Demo run", startAt: date, endAt: end)
            try await event.save(on: req.db)
        }

        return SeedResponse(message: "Seed complete", userEmail: demoEmail, password: demoPassword)
    }

    private func upcomingMWFDates(count: Int, after date: Date, calendar: Calendar) -> [Date] {
        var results: [Date] = []
        var cursor = calendar.date(byAdding: .day, value: 1, to: date)!
        while results.count < count {
            let weekday = calendar.component(.weekday, from: cursor) // 2=Mon,4=Wed,6=Fri
            if [2, 4, 6].contains(weekday) {
                var comps = calendar.dateComponents([.year, .month, .day], from: cursor)
                comps.hour = 7; comps.minute = 0; comps.second = 0
                comps.timeZone = TimeZone(identifier: "UTC")
                if let d = calendar.date(from: comps) { results.append(d) }
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return results
    }
}
```

- [ ] **Step 4: Register controller in routes.swift**

Add to `routes.swift`:
```swift
try app.register(collection: AdminController())
```

- [ ] **Step 5: Build**

```bash
swift build
```
Expected: `Build complete!`

---

## Task 7: Admin — Tests

**Files:**
- Create: `api/Tests/AppTests/AdminControllerTests.swift`

- [ ] **Step 1: Write tests**

`api/Tests/AppTests/AdminControllerTests.swift`:
```swift
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
        let demoUser = try await User.query(on: app.db)
            .filter(\.$email == "demo@habitflow.app")
            .first()
        let demoUserID = try XCTUnwrap(demoUser).requireID()
        let count = try await Habit.query(on: app.db)
            .filter(\.$user.$id == demoUserID)
            .count()
        XCTAssertEqual(count, 4)
    }
}
```

- [ ] **Step 2: Run tests**

```bash
swift test --filter AppTests/AdminControllerTests
```
Expected: all 4 tests pass.

- [ ] **Step 3: Run full suite**

```bash
swift test
```
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add api/Sources/App/Middleware/AdminMiddleware.swift \
        api/Sources/App/DTOs/AdminDTOs.swift \
        api/Sources/App/Controllers/AdminController.swift \
        api/Sources/App/routes.swift \
        api/Tests/AppTests/AdminControllerTests.swift
git commit -m "feat: add Admin endpoints — GET /admin/users, PATCH role, POST /admin/seed"
```

---

## Done checklist

- [ ] `swift build` clean, 0 warnings
- [ ] `swift test` — all tests green
- [ ] `GET /calendar?start=&end=` returns events in range
- [ ] `POST /calendar` creates event, `PATCH` updates, `DELETE` soft-deletes
- [ ] `POST /ai/chat` returns `{reply, calendarUpdated}` (smoke with real API key)
- [ ] `POST /ai/chat` with "schedule Mon/Wed/Fri runs" creates CalendarEvents and returns `calendarUpdated: true`
- [ ] `GET /admin/users` returns 403 for non-admin, list for admin
- [ ] `PATCH /admin/users/:id/role` promotes free → premium
- [ ] `POST /admin/seed` creates demo user + 4 habits + 8 days logs + 3 calendar events; second call is a no-op
- [ ] Update `docs/progress.md` with Day 3–6 entries
