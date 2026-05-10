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
        protected.post(":eventID", "restore", use: restore)
    }

    // MARK: GET /calendar?start=&end=
    @Sendable
    func index(req: Request) async throws -> Page<CalendarEventResponse> {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

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
        let total = try await CalendarEvent.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$startAt >= start)
            .filter(\.$startAt < end)
            .count()
        let events = try await CalendarEvent.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$startAt >= start)
            .filter(\.$startAt < end)
            .sort(\.$startAt, .ascending)
            .range(paging.offset..<(paging.offset + paging.clampedPer))
            .all()

        return Page(
            items: try events.map { try CalendarEventResponse($0) },
            metadata: PageMetadata(page: max(paging.page, 1), per: paging.clampedPer, total: total)
        )
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

    // MARK: POST /calendar/:eventID/restore
    @Sendable
    func restore(req: Request) async throws -> CalendarEventResponse {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        guard let eventID = req.parameters.get("eventID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "invalid event ID")
        }
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

    // MARK: - Private
    private func findEventOrAbort(req: Request, userID: UUID) async throws -> CalendarEvent {
        guard let eventID = req.parameters.get("eventID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "invalid event ID")
        }
        // Fluent auto-excludes soft-deleted rows (deleted_at IS NOT NULL) via @Timestamp(on: .delete)
        guard let event = try await CalendarEvent.find(eventID, on: req.db) else {
            throw Abort(.notFound)
        }
        guard event.$user.id == userID else {
            throw Abort(.forbidden, reason: "Not your event")
        }
        return event
    }
}
