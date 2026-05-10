# Known Limitations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 10 known API limitations plus a blocking date-format bug that prevents Tai's iOS app from POSTing calendar events.

**Architecture:** All changes are in `api/Sources/App/`. New Fluent models get a paired migration registered in `configure.swift`. Auth denylist adds one indexed DB lookup per request. AI improvements extend `AICoachService` in place. All other changes are controller-level validations, new routes, or DTO additions.

**Tech Stack:** Swift 6 / Vapor 4 / Fluent (PostgreSQL) / JWT / Gemini REST API

**Run all tests:** `cd api && docker compose up -d && swift test`  
**Run a single class:** `swift test --filter AppTests/<ClassName>`

---

## File Map

| Status | Path | Change |
|--------|------|--------|
| Modify | `Sources/App/configure.swift` | ISO 8601 config (Task 0), register 2 new migrations (Tasks 1, 5) |
| Create | `Sources/App/Models/RevokedToken.swift` | New model (Task 1) |
| Create | `Sources/App/Migrations/AddRevokedTokens.swift` | New migration (Task 1) |
| Modify | `Sources/App/Middleware/UserPayload.swift` | Add `jti` claim (Task 2) |
| Modify | `Sources/App/Controllers/AuthController.swift` | `issueToken` adds jti; `logout` saves denylist row (Task 2) |
| Modify | `Sources/App/Middleware/JWTAuthenticator.swift` | Check denylist (Task 2) |
| Create | `Tests/AppTests/AuthControllerTests.swift` | Denylist test (Task 2) |
| Modify | `Sources/App/DTOs/AICoachDTOs.swift` | Add `CreatedEventResponse`, update `ChatResponse` (Task 3) |
| Modify | `Sources/App/Services/AICoachService.swift` | Events, multi-tool loop, history, weekday anchors (Tasks 3–7) |
| Modify | `Sources/App/Controllers/AICoachController.swift` | Map events into response (Task 3) |
| Create | `Sources/App/Models/AIConversation.swift` | New model + `StoredMessage` (Task 5) |
| Create | `Sources/App/Migrations/CreateAIConversation.swift` | New migration (Task 5) |
| Modify | `Sources/App/DTOs/HabitDTOs.swift` | Add `HabitFrequency` enum, `frequency` to `UpdateHabitRequest` (Task 8) |
| Modify | `Sources/App/Controllers/HabitController.swift` | Frequency validation, past-log deletion, premium gate (Tasks 8–11) |
| Modify | `Sources/App/Controllers/CalendarEventController.swift` | Restore endpoint (Task 9) |
| Modify | `Sources/App/Controllers/AdminController.swift` | User delete endpoint (Task 10) |
| Create | `Sources/App/DTOs/PageDTOs.swift` | `Page<T>`, `PageMetadata`, `PageRequest` (Task 11) |

---

## Task 0: Fix ISO 8601 Date Encoding/Decoding (Blocker)

**Files:**
- Modify: `api/Sources/App/configure.swift`
- Modify: `api/Tests/AppTests/CalendarEventControllerTests.swift`

> Vapor's default `JSONEncoder/JSONDecoder` uses Swift's `.deferredToDate` — dates as `Double` (seconds since 2001-01-01). The API spec promises ISO 8601 strings. Tai's iOS sends ISO 8601 strings → 400 on every date field. Fix: configure ISO 8601 globally before routes.

- [ ] **Write the failing test** — add to `CalendarEventControllerTests.swift` before the `// MARK: - Tests` comment:

```swift
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
        }
    )
}
```

- [ ] **Run the test to confirm it fails**

```bash
cd api && swift test --filter AppTests/CalendarEventControllerTests/testCreateEventAcceptsISO8601DateStrings
```

Expected: FAIL (400 bad request — date string can't decode as Double)

- [ ] **Add ISO 8601 content configuration to `configure.swift`** — insert just before `try routes(app)`:

```swift
// MARK: Content — ISO 8601 dates throughout (matches API spec and iOS client)
let iso8601Encoder = JSONEncoder()
iso8601Encoder.dateEncodingStrategy = .iso8601
let iso8601Decoder = JSONDecoder()
iso8601Decoder.dateDecodingStrategy = .iso8601
app.content.use(encoder: iso8601Encoder, for: .json)
app.content.use(decoder: iso8601Decoder, for: .json)
```

- [ ] **Run the test to confirm it passes**

```bash
cd api && swift test --filter AppTests/CalendarEventControllerTests/testCreateEventAcceptsISO8601DateStrings
```

Expected: PASS

- [ ] **Run the full test suite to confirm no regressions**

```bash
cd api && swift test
```

Expected: All tests pass.

- [ ] **Commit**

```bash
git add api/Sources/App/configure.swift api/Tests/AppTests/CalendarEventControllerTests.swift
git commit -m "fix: configure ISO 8601 date encoding/decoding — fixes POST /calendar from iOS"
```

---

## Task 1: RevokedToken Model + Migration

**Files:**
- Create: `api/Sources/App/Models/RevokedToken.swift`
- Create: `api/Sources/App/Migrations/AddRevokedTokens.swift`
- Modify: `api/Sources/App/configure.swift`

- [ ] **Create `RevokedToken.swift`**

```swift
import Vapor
import Fluent

final class RevokedToken: Model, @unchecked Sendable {
    static let schema = "revoked_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "jti")
    var jti: String

    @Field(key: "expires_at")
    var expiresAt: Date

    init() {}

    init(jti: String, expiresAt: Date) {
        self.jti = jti
        self.expiresAt = expiresAt
    }
}
```

- [ ] **Create `AddRevokedTokens.swift`**

```swift
import Fluent

struct AddRevokedTokens: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("revoked_tokens")
            .id()
            .field("jti", .string, .required)
            .field("expires_at", .datetime, .required)
            .unique(on: "jti")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("revoked_tokens").delete()
    }
}
```

- [ ] **Register the migration in `configure.swift`** — add after `app.migrations.add(CreateCalendarEvent())`:

```swift
app.migrations.add(AddRevokedTokens())
```

- [ ] **Build to confirm it compiles**

```bash
cd api && swift build
```

Expected: Build succeeded.

- [ ] **Commit**

```bash
git add api/Sources/App/Models/RevokedToken.swift \
        api/Sources/App/Migrations/AddRevokedTokens.swift \
        api/Sources/App/configure.swift
git commit -m "feat: add RevokedToken model and migration"
```

---

## Task 2: JWT Denylist — Wire UserPayload, AuthController, JWTAuthenticator

**Files:**
- Modify: `api/Sources/App/Middleware/UserPayload.swift`
- Modify: `api/Sources/App/Controllers/AuthController.swift`
- Modify: `api/Sources/App/Middleware/JWTAuthenticator.swift`
- Create: `api/Tests/AppTests/AuthControllerTests.swift`

> **Note:** Adding `jti` as a required JWT claim invalidates all tokens issued before this change (they lack the field). For the local demo this is acceptable — users log in again.

- [ ] **Write the failing test** — create `api/Tests/AppTests/AuthControllerTests.swift`:

```swift
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
}
```

- [ ] **Run to confirm it fails**

```bash
cd api && swift test --filter AppTests/AuthControllerTests/testLogoutInvalidatesToken
```

Expected: FAIL (logout returns 204 but token is still accepted afterwards)

- [ ] **Update `UserPayload.swift`** — add `jti: IDClaim`:

```swift
import Vapor
import JWT

struct UserPayload: JWTPayload, Authenticatable, Sendable {
    var sub: SubjectClaim
    var email: String
    var role: UserRole
    var exp: ExpirationClaim
    var jti: IDClaim

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.exp.verifyNotExpired()
    }

    var userID: UUID? {
        UUID(uuidString: sub.value)
    }
}
```

- [ ] **Update `issueToken` in `AuthController.swift`** — add `jti` to the payload:

```swift
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
```

- [ ] **Update `logout` in `AuthController.swift`** — replace the current stub body:

```swift
@Sendable
func logout(req: Request) async throws -> HTTPStatus {
    guard let rawToken = req.headers.bearerAuthorization?.token,
          let payload = try? await req.jwt.verify(rawToken, as: UserPayload.self) else {
        return .noContent
    }
    let revoked = RevokedToken(jti: payload.jti.value, expiresAt: payload.exp.value)
    try await revoked.save(on: req.db)
    return .noContent
}
```

- [ ] **Update `JWTAuthenticator.swift`** — check denylist after verification:

```swift
import Vapor
import JWT

struct JWTAuthenticator: AsyncBearerAuthenticator {
    typealias User = UserPayload

    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        let payload = try await request.jwt.verify(bearer.token, as: UserPayload.self)
        if try await RevokedToken.query(on: request.db)
            .filter(\.$jti == payload.jti.value)
            .first() != nil {
            throw Abort(.unauthorized, reason: "token has been revoked")
        }
        request.auth.login(payload)
    }
}
```

- [ ] **Run both denylist tests**

```bash
cd api && swift test --filter AppTests/AuthControllerTests
```

Expected: Both pass.

- [ ] **Run full suite**

```bash
cd api && swift test
```

Expected: All pass.

- [ ] **Commit**

```bash
git add api/Sources/App/Middleware/UserPayload.swift \
        api/Sources/App/Controllers/AuthController.swift \
        api/Sources/App/Middleware/JWTAuthenticator.swift \
        api/Tests/AppTests/AuthControllerTests.swift
git commit -m "feat: implement JWT logout denylist — revoked tokens rejected immediately"
```

---

## Task 3: AI — ChatResponse Events Field

**Files:**
- Modify: `api/Sources/App/DTOs/AICoachDTOs.swift`
- Modify: `api/Sources/App/Services/AICoachService.swift`
- Modify: `api/Sources/App/Controllers/AICoachController.swift`

> No automated test — `GeminiClient` makes live network calls and has no mock infrastructure. Verify manually after implementation.

- [ ] **Update `AICoachDTOs.swift`** — add `CreatedEventResponse` and update `ChatResponse`:

```swift
struct CreatedEventResponse: Content, Sendable {
    let title: String
    let startTime: Date
}

struct ChatResponse: Content, Sendable {
    let reply: String
    let calendarUpdated: Bool
    let events: [CreatedEventResponse]?
}
```

- [ ] **Update `AICoachService.swift`** — change `executeFunction` for `write_calendar` to return created events, and change `chat` return type. Replace the entire file:

```swift
import Vapor
import Fluent

struct AICoachService: Sendable {
    private let gemini: GeminiClient

    init(gemini: GeminiClient) {
        self.gemini = gemini
    }

    func chat(
        message: String,
        userID: UUID,
        req: Request
    ) async throws -> (reply: String, calendarUpdated: Bool, createdEvents: [CalendarEvent]) {
        var contents: [GeminiContent] = [
            GeminiContent(role: "user", parts: [GeminiPart(text: message)])
        ]
        let systemInstruction = GeminiSystemInstruction(parts: [
            GeminiPart(text: buildSystemPrompt())
        ])
        let request = GeminiGenerateRequest(systemInstruction: systemInstruction, tools: [buildTools()], contents: contents)

        var calendarUpdated = false
        var allCreatedEvents: [CalendarEvent] = []

        // Multi-tool loop — up to 5 function-call round-trips
        var currentRequest = request
        for _ in 0..<5 {
            let response = try await gemini.generateContent(currentRequest, on: req)
            guard let candidate = response.candidates.first else {
                throw Abort(.badGateway, reason: "AI returned no response")
            }

            guard let functionCall = candidate.content.parts.compactMap({ $0.functionCall }).first else {
                // No function call — return the text reply
                guard let text = candidate.content.parts.first?.text else {
                    throw Abort(.badGateway, reason: "AI returned no response")
                }
                return (reply: text, calendarUpdated: calendarUpdated, createdEvents: allCreatedEvents)
            }

            let (funcResponse, didUpdateCalendar, newEvents) = try await executeFunction(functionCall, userID: userID, req: req)
            if didUpdateCalendar {
                calendarUpdated = true
                allCreatedEvents.append(contentsOf: newEvents)
            }

            var updatedContents = currentRequest.contents
            updatedContents.append(candidate.content)
            updatedContents.append(GeminiContent(role: "user", parts: [GeminiPart(functionResponse: funcResponse)]))
            currentRequest.contents = updatedContents
        }

        throw Abort(.badGateway, reason: "AI exceeded maximum tool call iterations")
    }

    // MARK: - Function execution

    private func executeFunction(
        _ call: GeminiFunctionCall,
        userID: UUID,
        req: Request
    ) async throws -> (GeminiFunctionResponse, Bool, [CalendarEvent]) {
        switch call.name {
        case "get_user_habits":
            let habits = try await Habit.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$isActive == true)
                .all()
            let summary = habits.isEmpty
                ? "No active habits found."
                : habits.map { "\($0.name) (\($0.category ?? "general"), \($0.frequency))" }.joined(separator: "; ")
            return (GeminiFunctionResponse(name: "get_user_habits", response: ["result": summary]), false, [])

        case "write_calendar":
            guard let eventArgs = call.args.events, !eventArgs.isEmpty else {
                return (GeminiFunctionResponse(name: "write_calendar", response: ["result": "No events provided."]), false, [])
            }
            let events: [CalendarEvent] = {
                var iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime]
                return eventArgs.compactMap { arg in
                    guard let start = iso.date(from: arg.startAt),
                          let end = iso.date(from: arg.endAt),
                          end > start else { return nil }
                    return CalendarEvent(userID: userID, title: arg.title, notes: arg.notes, startAt: start, endAt: end)
                }
            }()
            for event in events {
                try await event.save(on: req.db)
            }
            let created = events.count
            let result = created == 0
                ? "No valid events created."
                : "Created \(created) calendar event\(created == 1 ? "" : "s")."
            return (GeminiFunctionResponse(name: "write_calendar", response: ["result": result]), created > 0, events)

        default:
            return (GeminiFunctionResponse(name: call.name, response: ["result": "Unknown function."]), false, [])
        }
    }

    // MARK: - System prompt

    private func buildSystemPrompt() -> String {
        let todayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd (EEEE)"
            f.timeZone = TimeZone(identifier: "UTC")!
            return f
        }()
        let dateOnlyFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "UTC")!
            return f
        }()
        let weekdayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            f.timeZone = TimeZone(identifier: "UTC")!
            return f
        }()

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let today = Date()
        let todayStr = todayFormatter.string(from: today)

        var anchors: [String] = []
        for i in 1...14 {
            let d = cal.date(byAdding: .day, value: i, to: today)!
            anchors.append("\(weekdayFormatter.string(from: d))=\(dateOnlyFormatter.string(from: d))")
        }

        return """
        Today is \(todayStr) UTC. Use this when creating or referencing calendar events.
        Upcoming dates: \(anchors.joined(separator: ", ")).
        Use ISO8601 UTC format for all event times, e.g. 2026-05-11T07:00:00Z.
        """
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

- [ ] **Update `AICoachController.swift`** — map created events into the response:

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
        let (reply, calendarUpdated, createdEvents) = try await service.chat(
            message: body.message, userID: userID, req: req
        )

        let events: [CreatedEventResponse]? = calendarUpdated && !createdEvents.isEmpty
            ? createdEvents.map { CreatedEventResponse(title: $0.title, startTime: $0.startAt) }
            : nil

        return ChatResponse(reply: reply, calendarUpdated: calendarUpdated, events: events)
    }
}
```

- [ ] **Build to confirm it compiles**

```bash
cd api && swift build
```

Expected: Build succeeded.

- [ ] **Commit**

```bash
git add api/Sources/App/DTOs/AICoachDTOs.swift \
        api/Sources/App/Services/AICoachService.swift \
        api/Sources/App/Controllers/AICoachController.swift
git commit -m "feat: add events field to ChatResponse, multi-tool loop, weekday anchors in system prompt"
```

---

## Task 4: AIConversation Model + Migration

**Files:**
- Create: `api/Sources/App/Models/AIConversation.swift`
- Create: `api/Sources/App/Migrations/CreateAIConversation.swift`
- Modify: `api/Sources/App/configure.swift`

- [ ] **Create `AIConversation.swift`**

```swift
import Vapor
import Fluent

struct StoredMessage: Codable, Sendable {
    let role: String   // "user" or "model"
    let text: String
}

final class AIConversation: Model, @unchecked Sendable {
    static let schema = "ai_conversations"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "messages_json")
    var messagesJSON: String

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(userID: UUID) {
        self.$user.id = userID
        self.messagesJSON = "[]"
    }
}
```

- [ ] **Create `CreateAIConversation.swift`**

```swift
import Fluent

struct CreateAIConversation: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("ai_conversations")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("messages_json", .string, .required)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("ai_conversations").delete()
    }
}
```

- [ ] **Register in `configure.swift`** — add after `app.migrations.add(AddRevokedTokens())`:

```swift
app.migrations.add(CreateAIConversation())
```

- [ ] **Build to confirm it compiles**

```bash
cd api && swift build
```

Expected: Build succeeded.

- [ ] **Commit**

```bash
git add api/Sources/App/Models/AIConversation.swift \
        api/Sources/App/Migrations/CreateAIConversation.swift \
        api/Sources/App/configure.swift
git commit -m "feat: add AIConversation model and migration for conversation history"
```

---

## Task 5: AI Conversation History — Service Integration

**Files:**
- Modify: `api/Sources/App/Services/AICoachService.swift`

> Adds conversation history to `chat`. No automated test (live Gemini dependency). Verify manually: send two messages, the second should reference the first.

- [ ] **Add `loadConversation` helper and update `chat` in `AICoachService.swift`**

Add the following private helper to `AICoachService` (before `buildSystemPrompt`):

```swift
private func loadConversation(userID: UUID, db: any Database) async throws -> AIConversation {
    if let existing = try await AIConversation.query(on: db)
        .filter(\.$user.$id == userID)
        .first() {
        return existing
    }
    let conv = AIConversation(userID: userID)
    try await conv.save(on: db)
    return conv
}
```

Replace the `chat` function (keep the signature identical, update the body to load/save history):

```swift
func chat(
    message: String,
    userID: UUID,
    req: Request
) async throws -> (reply: String, calendarUpdated: Bool, createdEvents: [CalendarEvent]) {
    let conversation = try await loadConversation(userID: userID, db: req.db)

    // Decode stored messages and build prior GeminiContent turns
    let decoder = JSONDecoder()
    let stored = (try? decoder.decode([StoredMessage].self, from: Data(conversation.messagesJSON.utf8))) ?? []
    var contents: [GeminiContent] = stored.map {
        GeminiContent(role: $0.role, parts: [GeminiPart(text: $0.text)])
    }
    contents.append(GeminiContent(role: "user", parts: [GeminiPart(text: message)]))

    let systemInstruction = GeminiSystemInstruction(parts: [
        GeminiPart(text: buildSystemPrompt())
    ])
    let request = GeminiGenerateRequest(systemInstruction: systemInstruction, tools: [buildTools()], contents: contents)

    var calendarUpdated = false
    var allCreatedEvents: [CalendarEvent] = []
    var currentRequest = request
    var finalReply = ""

    for _ in 0..<5 {
        let response = try await gemini.generateContent(currentRequest, on: req)
        guard let candidate = response.candidates.first else {
            throw Abort(.badGateway, reason: "AI returned no response")
        }

        guard let functionCall = candidate.content.parts.compactMap({ $0.functionCall }).first else {
            guard let text = candidate.content.parts.first?.text else {
                throw Abort(.badGateway, reason: "AI returned no response")
            }
            finalReply = text
            break
        }

        let (funcResponse, didUpdateCalendar, newEvents) = try await executeFunction(functionCall, userID: userID, req: req)
        if didUpdateCalendar {
            calendarUpdated = true
            allCreatedEvents.append(contentsOf: newEvents)
        }

        var updatedContents = currentRequest.contents
        updatedContents.append(candidate.content)
        updatedContents.append(GeminiContent(role: "user", parts: [GeminiPart(functionResponse: funcResponse)]))
        currentRequest.contents = updatedContents
    }

    guard !finalReply.isEmpty else {
        throw Abort(.badGateway, reason: "AI exceeded maximum tool call iterations")
    }

    // Persist updated history (cap at 20 messages)
    var updatedMessages = stored
    updatedMessages.append(StoredMessage(role: "user", text: message))
    updatedMessages.append(StoredMessage(role: "model", text: finalReply))
    let capped = Array(updatedMessages.suffix(20))
    let encoder = JSONEncoder()
    conversation.messagesJSON = (try? String(data: encoder.encode(capped), encoding: .utf8)) ?? "[]"
    try await conversation.save(on: req.db)

    return (reply: finalReply, calendarUpdated: calendarUpdated, createdEvents: allCreatedEvents)
}
```

- [ ] **Build to confirm it compiles**

```bash
cd api && swift build
```

Expected: Build succeeded.

- [ ] **Commit**

```bash
git add api/Sources/App/Services/AICoachService.swift
git commit -m "feat: add AI conversation history — persists last 20 messages per user"
```

---

## Task 6: Habit Frequency Validation

**Files:**
- Modify: `api/Sources/App/DTOs/HabitDTOs.swift`
- Modify: `api/Sources/App/Controllers/HabitController.swift`

- [ ] **Write the failing test** — add to `HabitControllerTests.swift`:

```swift
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
```

- [ ] **Run to confirm they fail**

```bash
cd api && swift test --filter AppTests/HabitControllerTests/testCreateHabitRejectsInvalidFrequency
```

Expected: FAIL (compile error — `UpdateHabitRequest` doesn't have `frequency` yet, or test passes unexpectedly)

- [ ] **Add `HabitFrequency` enum and `frequency` to `UpdateHabitRequest` in `HabitDTOs.swift`**

Add at the top of the file, before the request structs:

```swift
enum HabitFrequency: String, CaseIterable {
    case daily, weekly, monthly, custom
}
```

Add `frequency: String?` to `UpdateHabitRequest`:

```swift
struct UpdateHabitRequest: Content, Sendable {
    let name: String?
    let category: String?
    let targetTime: String?
    let description: String?
    let isActive: Bool?
    let frequency: String?
}
```

- [ ] **Add frequency validation helper and update `create` and `update` in `HabitController.swift`**

Add this private helper to `HabitController` (before `utcDayBounds`):

```swift
private func validatedFrequency(_ raw: String) throws -> String {
    guard HabitFrequency(rawValue: raw) != nil else {
        let valid = HabitFrequency.allCases.map(\.rawValue).joined(separator: ", ")
        throw Abort(.badRequest, reason: "invalid frequency — valid values: \(valid)")
    }
    return raw
}
```

In `create`, replace the frequency line inside habit construction:

```swift
let frequency = try validatedFrequency(body.frequency ?? "daily")
let habit = Habit(
    userID: userID,
    name: name,
    category: body.category,
    frequency: frequency,
    targetTime: body.targetTime,
    description: body.description
)
```

In `update`, add after the `isActive` check:

```swift
if let frequency = body.frequency {
    habit.frequency = try validatedFrequency(frequency)
}
```

- [ ] **Run the tests**

```bash
cd api && swift test --filter AppTests/HabitControllerTests/testCreateHabitRejectsInvalidFrequency
cd api && swift test --filter AppTests/HabitControllerTests/testUpdateHabitRejectsInvalidFrequency
```

Expected: Both PASS.

- [ ] **Run full suite**

```bash
cd api && swift test
```

Expected: All pass.

- [ ] **Commit**

```bash
git add api/Sources/App/DTOs/HabitDTOs.swift \
        api/Sources/App/Controllers/HabitController.swift \
        api/Tests/AppTests/HabitControllerTests.swift
git commit -m "feat: validate habit frequency — only daily/weekly/monthly/custom accepted"
```

---

## Task 7: Past Log Deletion by Date

**Files:**
- Modify: `api/Sources/App/Controllers/HabitController.swift`

- [ ] **Write the failing test** — add to `HabitControllerTests.swift`:

```swift
func testUnlogPastDate() async throws {
    let token = try await register()
    let habit = try await makeHabit(token: token)

    // Log for yesterday (completedAt in the past)
    let yesterday = Date().addingTimeInterval(-86400)
    try await app.test(.POST, "habits/\(habit.id)/log",
        headers: bearer(token),
        beforeRequest: { req in
            try req.content.encode(LogHabitRequest(completedAt: yesterday, notes: nil))
        },
        afterResponse: { res async throws in XCTAssertEqual(res.status, .created) }
    )

    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.timeZone = TimeZone(identifier: "UTC")!
    let yesterdayStr = fmt.string(from: yesterday)

    try await app.test(.DELETE, "habits/\(habit.id)/log?date=\(yesterdayStr)",
        headers: bearer(token),
        afterResponse: { res async throws in XCTAssertEqual(res.status, .noContent) }
    )
}

func testUnlogReturnsWith404WhenNoLogExists() async throws {
    let token = try await register()
    let habit = try await makeHabit(token: token)

    try await app.test(.DELETE, "habits/\(habit.id)/log?date=2020-01-01",
        headers: bearer(token),
        afterResponse: { res async throws in XCTAssertEqual(res.status, .notFound) }
    )
}
```

- [ ] **Run to confirm they fail**

```bash
cd api && swift test --filter AppTests/HabitControllerTests/testUnlogPastDate
```

Expected: FAIL (422 or 404 — `?date=` param not handled)

- [ ] **Update `unlogHabit` in `HabitController.swift`**

Replace the `unlogHabit` function body:

```swift
@Sendable
func unlogHabit(req: Request) async throws -> HTTPStatus {
    let payload = try req.auth.require(UserPayload.self)
    guard let userID = payload.userID else { throw Abort(.unauthorized) }

    let habit = try await findHabitOrAbort(req: req, userID: userID)
    guard let habitID = habit.id else { throw Abort(.internalServerError) }

    // Optional ?date=yyyy-MM-dd query param; defaults to today UTC
    let targetDate: Date
    if let dateStr = req.query[String.self, at: "date"] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")!
        guard let parsed = fmt.date(from: dateStr) else {
            throw Abort(.badRequest, reason: "invalid date — use yyyy-MM-dd format, e.g. 2026-05-07")
        }
        targetDate = parsed
    } else {
        targetDate = Date()
    }

    let (dayStart, tomorrowStart) = utcDayBounds(for: targetDate)

    guard let log = try await HabitLog.query(on: req.db)
        .filter(\.$habit.$id == habitID)
        .filter(\.$user.$id == userID)
        .filter(\.$completedAt >= dayStart)
        .filter(\.$completedAt < tomorrowStart)
        .sort(\.$completedAt, .descending)
        .first()
    else {
        throw Abort(.notFound, reason: "no log found for that date")
    }

    try await log.delete(force: true, on: req.db)
    return .noContent
}
```

- [ ] **Run the tests**

```bash
cd api && swift test --filter AppTests/HabitControllerTests/testUnlogPastDate
cd api && swift test --filter AppTests/HabitControllerTests/testUnlogReturnsWith404WhenNoLogExists
```

Expected: Both PASS.

- [ ] **Run full suite**

```bash
cd api && swift test
```

Expected: All pass.

- [ ] **Commit**

```bash
git add api/Sources/App/Controllers/HabitController.swift \
        api/Tests/AppTests/HabitControllerTests.swift
git commit -m "feat: allow DELETE /habits/:id/log?date=yyyy-MM-dd for past log removal"
```

---

## Task 8: Calendar Event Restore

**Files:**
- Modify: `api/Sources/App/Controllers/CalendarEventController.swift`

- [ ] **Write the failing test** — add to `CalendarEventControllerTests.swift`:

```swift
func testRestoreDeletedEvent() async throws {
    let token = try await register()
    let event = try await makeEvent(token: token)

    // Delete it
    try await app.test(.DELETE, "calendar/\(event.id)", headers: bearer(token),
        afterResponse: { res async throws in XCTAssertEqual(res.status, .noContent) }
    )

    // Restore it
    try await app.test(.POST, "calendar/\(event.id)/restore", headers: bearer(token),
        afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let restored = try res.content.decode(CalendarEventResponse.self)
            XCTAssertEqual(restored.id, event.id)
            XCTAssertEqual(restored.title, event.title)
        }
    )
}

func testRestoreReturns404ForNonDeletedEvent() async throws {
    let token = try await register()
    let event = try await makeEvent(token: token)

    // Event exists and is NOT deleted — restore should 404
    try await app.test(.POST, "calendar/\(event.id)/restore", headers: bearer(token),
        afterResponse: { res async throws in XCTAssertEqual(res.status, .notFound) }
    )
}
```

- [ ] **Run to confirm they fail**

```bash
cd api && swift test --filter AppTests/CalendarEventControllerTests/testRestoreDeletedEvent
```

Expected: FAIL (404 — route doesn't exist)

- [ ] **Add `restore` route and handler to `CalendarEventController.swift`**

In `boot`, add after `protected.delete(":eventID", use: delete)`:

```swift
protected.post(":eventID", "restore", use: restore)
```

Add the handler after the `delete` function:

```swift
// MARK: POST /calendar/:eventID/restore
@Sendable
func restore(req: Request) async throws -> CalendarEventResponse {
    let payload = try req.auth.require(UserPayload.self)
    guard let userID = payload.userID else { throw Abort(.unauthorized) }

    guard let eventID = req.parameters.get("eventID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "invalid event ID")
    }
    // Must use withDeleted() to find soft-deleted rows
    guard let event = try await CalendarEvent.query(on: req.db)
        .withDeleted()
        .filter(\.$id == eventID)
        .filter(\.$deletedAt != nil)
        .first()
    else {
        throw Abort(.notFound)
    }
    guard event.$user.id == userID else {
        throw Abort(.forbidden, reason: "Not your event")
    }

    event.deletedAt = nil
    try await event.update(on: req.db)
    return try CalendarEventResponse(event)
}
```

- [ ] **Run the tests**

```bash
cd api && swift test --filter AppTests/CalendarEventControllerTests/testRestoreDeletedEvent
cd api && swift test --filter AppTests/CalendarEventControllerTests/testRestoreReturns404ForNonDeletedEvent
```

Expected: Both PASS.

- [ ] **Run full suite**

```bash
cd api && swift test
```

Expected: All pass.

- [ ] **Commit**

```bash
git add api/Sources/App/Controllers/CalendarEventController.swift \
        api/Tests/AppTests/CalendarEventControllerTests.swift
git commit -m "feat: add POST /calendar/:id/restore endpoint"
```

---

## Task 9: Premium Feature Gating

**Files:**
- Modify: `api/Sources/App/Controllers/HabitController.swift`

- [ ] **Write the failing test** — add to `HabitControllerTests.swift`:

```swift
func testFreeUserCanCreateUpToFiveHabits() async throws {
    let token = try await register()
    for i in 1...5 {
        try await app.test(.POST, "habits",
            headers: bearer(token),
            beforeRequest: { req in
                try req.content.encode(CreateHabitRequest(
                    name: "Habit \(i)", category: nil, frequency: "daily",
                    targetTime: nil, description: nil
                ))
            },
            afterResponse: { res async throws in XCTAssertEqual(res.status, .created) }
        )
    }
    // 6th habit is rejected
    try await app.test(.POST, "habits",
        headers: bearer(token),
        beforeRequest: { req in
            try req.content.encode(CreateHabitRequest(
                name: "Habit 6", category: nil, frequency: "daily",
                targetTime: nil, description: nil
            ))
        },
        afterResponse: { res async throws in XCTAssertEqual(res.status, .forbidden) }
    )
}
```

- [ ] **Run to confirm it fails**

```bash
cd api && swift test --filter AppTests/HabitControllerTests/testFreeUserCanCreateUpToFiveHabits
```

Expected: FAIL (6th habit creates successfully, 403 not returned)

- [ ] **Add premium gate in `HabitController.create`** — insert after the name validation, before constructing the `Habit`:

```swift
if payload.role == .free {
    let activeCount = try await Habit.query(on: req.db)
        .filter(\.$user.$id == userID)
        .filter(\.$isActive == true)
        .count()
    guard activeCount < 5 else {
        throw Abort(.forbidden, reason: "Upgrade to premium to create more than 5 habits")
    }
}
```

- [ ] **Run the test**

```bash
cd api && swift test --filter AppTests/HabitControllerTests/testFreeUserCanCreateUpToFiveHabits
```

Expected: PASS.

- [ ] **Run full suite**

```bash
cd api && swift test
```

Expected: All pass.

- [ ] **Commit**

```bash
git add api/Sources/App/Controllers/HabitController.swift \
        api/Tests/AppTests/HabitControllerTests.swift
git commit -m "feat: gate habit creation at 5 for free users — premium required for more"
```

---

## Task 10: Admin User Delete

**Files:**
- Modify: `api/Sources/App/Controllers/AdminController.swift`

- [ ] **Write the failing test** — add to `AdminControllerTests.swift`:

```swift
func testDeleteUser() async throws {
    let (adminToken, adminID) = try await register(email: "admin@test.com", name: "Admin", role: .admin)
    let (_, targetID) = try await register(email: "target@test.com", name: "Target")

    try await app.test(.DELETE, "admin/users/\(targetID)",
        headers: bearer(adminToken),
        afterResponse: { res async throws in XCTAssertEqual(res.status, .noContent) }
    )

    // Deleted user is absent from the list
    try await app.test(.GET, "admin/users",
        headers: bearer(adminToken),
        afterResponse: { res async throws in
            let users = try res.content.decode([AdminUserResponse].self)
            XCTAssertFalse(users.contains(where: { $0.id == targetID }))
        }
    )
}

func testDeleteUserCannotDeleteSelf() async throws {
    let (adminToken, adminID) = try await register(email: "admin2@test.com", name: "Admin2", role: .admin)

    try await app.test(.DELETE, "admin/users/\(adminID)",
        headers: bearer(adminToken),
        afterResponse: { res async throws in XCTAssertEqual(res.status, .badRequest) }
    )
}
```

- [ ] **Run to confirm they fail**

```bash
cd api && swift test --filter AppTests/AdminControllerTests/testDeleteUser
```

Expected: FAIL (404 — route doesn't exist)

- [ ] **Add delete route and handler to `AdminController.swift`**

In `boot`, add after `admin.post("seed", use: seed)`:

```swift
admin.delete("users", ":userID", use: deleteUser)
```

Add the handler after the `seed` function (before `upcomingMWFDates`):

```swift
// MARK: DELETE /admin/users/:userID
@Sendable
func deleteUser(req: Request) async throws -> HTTPStatus {
    let payload = try req.auth.require(UserPayload.self)
    guard let callerID = payload.userID else { throw Abort(.unauthorized) }

    guard let userID = req.parameters.get("userID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "invalid user ID")
    }
    guard userID != callerID else {
        throw Abort(.badRequest, reason: "cannot delete your own account")
    }
    guard let user = try await User.find(userID, on: req.db) else {
        throw Abort(.notFound, reason: "user not found")
    }
    try await user.delete(on: req.db)
    return .noContent
}
```

- [ ] **Run the tests**

```bash
cd api && swift test --filter AppTests/AdminControllerTests/testDeleteUser
cd api && swift test --filter AppTests/AdminControllerTests/testDeleteUserCannotDeleteSelf
```

Expected: Both PASS.

- [ ] **Run full suite**

```bash
cd api && swift test
```

Expected: All pass.

- [ ] **Commit**

```bash
git add api/Sources/App/Controllers/AdminController.swift \
        api/Tests/AppTests/AdminControllerTests.swift
git commit -m "feat: add DELETE /admin/users/:id endpoint"
```

---

## Task 11: Pagination

> ⚠️ **Breaking change.** `GET /habits`, `GET /calendar`, and `GET /admin/users` change from returning a bare array to a `Page<T>` envelope. Coordinate with Tai before merging this task. Existing tests for these endpoints need updating too.

**Files:**
- Create: `api/Sources/App/DTOs/PageDTOs.swift`
- Modify: `api/Sources/App/Controllers/HabitController.swift`
- Modify: `api/Sources/App/Controllers/CalendarEventController.swift`
- Modify: `api/Sources/App/Controllers/AdminController.swift`
- Modify: `api/Tests/AppTests/HabitControllerTests.swift`
- Modify: `api/Tests/AppTests/CalendarEventControllerTests.swift`
- Modify: `api/Tests/AppTests/AdminControllerTests.swift`

- [ ] **Create `PageDTOs.swift`**

```swift
import Vapor

struct PageMetadata: Content, Sendable {
    let page: Int
    let per: Int
    let total: Int
}

struct Page<T: Content & Sendable>: Content, Sendable {
    let items: [T]
    let metadata: PageMetadata
}

struct PageRequest: Content {
    var page: Int
    var per: Int

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        page = (try? c.decode(Int.self, forKey: .page)) ?? 1
        per  = (try? c.decode(Int.self, forKey: .per))  ?? 20
    }

    enum CodingKeys: String, CodingKey { case page, per }

    var clampedPer: Int { min(max(per, 1), 100) }
    var offset: Int { (max(page, 1) - 1) * clampedPer }
}
```

- [ ] **Update `HabitController.index`** — change return type and body:

```swift
@Sendable
func index(req: Request) async throws -> Page<HabitResponse> {
    let payload = try req.auth.require(UserPayload.self)
    guard let userID = payload.userID else { throw Abort(.unauthorized) }

    let paging = (try? req.query.decode(PageRequest.self)) ?? PageRequest()
    let total = try await Habit.query(on: req.db).filter(\.$user.$id == userID).count()
    let habits = try await Habit.query(on: req.db)
        .filter(\.$user.$id == userID)
        .sort(\.$createdAt, .ascending)
        .range(paging.offset..<(paging.offset + paging.clampedPer))
        .all()

    return Page(
        items: try habits.map { try HabitResponse($0) },
        metadata: PageMetadata(page: max(paging.page, 1), per: paging.clampedPer, total: total)
    )
}
```

Note: `PageRequest()` no-arg init isn't synthesized because of the custom `init(from:)`. Add a convenience init:

```swift
// In PageRequest, add:
init(page: Int = 1, per: Int = 20) {
    self.page = page
    self.per = per
}
```

- [ ] **Update `CalendarEventController.index`** — change return type and body:

```swift
@Sendable
func index(req: Request) async throws -> Page<CalendarEventResponse> {
    let payload = try req.auth.require(UserPayload.self)
    guard let userID = payload.userID else { throw Abort(.unauthorized) }

    let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime]
    let isoFrac = ISO8601DateFormatter(); isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    guard let startStr = req.query[String.self, at: "start"],
          let endStr = req.query[String.self, at: "end"] else {
        throw Abort(.badRequest, reason: "start and end query parameters are required (ISO8601, e.g. 2026-05-08T00:00:00Z)")
    }
    guard let start = iso.date(from: startStr) ?? isoFrac.date(from: startStr) else {
        throw Abort(.badRequest, reason: "invalid start — use ISO8601 e.g. 2026-05-08T00:00:00Z")
    }
    guard let end = iso.date(from: endStr) ?? isoFrac.date(from: endStr) else {
        throw Abort(.badRequest, reason: "invalid end — use ISO8601 e.g. 2026-05-08T23:59:59Z")
    }
    guard end > start else {
        throw Abort(.badRequest, reason: "end must be after start")
    }

    let paging = (try? req.query.decode(PageRequest.self)) ?? PageRequest()
    let baseQuery = CalendarEvent.query(on: req.db)
        .filter(\.$user.$id == userID)
        .filter(\.$startAt >= start)
        .filter(\.$startAt < end)
    let total = try await baseQuery.count()
    let events = try await baseQuery
        .sort(\.$startAt, .ascending)
        .range(paging.offset..<(paging.offset + paging.clampedPer))
        .all()

    return Page(
        items: try events.map { try CalendarEventResponse($0) },
        metadata: PageMetadata(page: max(paging.page, 1), per: paging.clampedPer, total: total)
    )
}
```

- [ ] **Update `AdminController.listUsers`** — change return type and body:

```swift
@Sendable
func listUsers(req: Request) async throws -> Page<AdminUserResponse> {
    let paging = (try? req.query.decode(PageRequest.self)) ?? PageRequest()
    let total = try await User.query(on: req.db).count()
    let users = try await User.query(on: req.db)
        .sort(\.$createdAt, .ascending)
        .range(paging.offset..<(paging.offset + paging.clampedPer))
        .all()

    return Page(
        items: try users.map { try AdminUserResponse($0) },
        metadata: PageMetadata(page: max(paging.page, 1), per: paging.clampedPer, total: total)
    )
}
```

- [ ] **Update tests** — in `HabitControllerTests`, `CalendarEventControllerTests`, and `AdminControllerTests`, change any `res.content.decode([HabitResponse].self)` → `res.content.decode(Page<HabitResponse>.self).items`, and similar for the other types. For example in `HabitControllerTests`:

```swift
// Before:
let habits = try res.content.decode([HabitResponse].self)
// After:
let page = try res.content.decode(Page<HabitResponse>.self)
let habits = page.items
```

Apply the same pattern for `[CalendarEventResponse]` → `Page<CalendarEventResponse>.items` and `[AdminUserResponse]` → `Page<AdminUserResponse>.items`.

- [ ] **Build to confirm it compiles**

```bash
cd api && swift build
```

- [ ] **Run full suite**

```bash
cd api && swift test
```

Expected: All pass.

- [ ] **Commit**

```bash
git add api/Sources/App/DTOs/PageDTOs.swift \
        api/Sources/App/Controllers/HabitController.swift \
        api/Sources/App/Controllers/CalendarEventController.swift \
        api/Sources/App/Controllers/AdminController.swift \
        api/Tests/AppTests/HabitControllerTests.swift \
        api/Tests/AppTests/CalendarEventControllerTests.swift \
        api/Tests/AppTests/AdminControllerTests.swift
git commit -m "feat: add offset-based pagination to GET /habits, GET /calendar, GET /admin/users"
```
