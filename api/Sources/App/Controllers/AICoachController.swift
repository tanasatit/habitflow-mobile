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
            message: body.message, timezone: body.timezone, userID: userID, req: req
        )

        let events: [CreatedEventResponse]? = calendarUpdated && !createdEvents.isEmpty
            ? createdEvents.map { CreatedEventResponse(title: $0.title, startTime: $0.startAt) }
            : nil

        return ChatResponse(reply: reply, calendarUpdated: calendarUpdated, events: events)
    }
}
