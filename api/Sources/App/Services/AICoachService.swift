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
