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

        for _ in 0..<5 {
            let response = try await gemini.generateContent(currentRequest, on: req)
            guard let candidate = response.candidates.first else {
                throw Abort(.badGateway, reason: "AI returned no response")
            }

            guard let functionCall = candidate.content.parts.compactMap({ $0.functionCall }).first else {
                guard let text = candidate.content.parts.first?.text else {
                    throw Abort(.badGateway, reason: "AI returned no response")
                }
                // Persist updated history (cap at 20 messages)
                var updatedMessages = stored
                updatedMessages.append(StoredMessage(role: "user", text: message))
                updatedMessages.append(StoredMessage(role: "model", text: text))
                let capped = Array(updatedMessages.suffix(20))
                let encoder = JSONEncoder()
                conversation.messagesJSON = (try? String(data: encoder.encode(capped), encoding: .utf8)) ?? "[]"
                try await conversation.save(on: req.db)
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
                let iso = ISO8601DateFormatter()
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

    // MARK: - Conversation history

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
