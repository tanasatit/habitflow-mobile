import Vapor
import Fluent

struct HabitController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let protected = routes
            .grouped("habits")
            .grouped(JWTAuthenticator(), UserPayload.guardMiddleware())

        protected.get(use: index)
        protected.post(use: create)
        protected.get(":habitID", use: show)
        protected.put(":habitID", use: update)
        protected.delete(":habitID", use: delete)
        protected.post(":habitID", "log", use: logHabit)
        protected.delete(":habitID", "log", use: unlogHabit)
        protected.get(":habitID", "stats", use: stats)
    }

    // MARK: GET /habits
    @Sendable
    func index(req: Request) async throws -> [HabitResponse] {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let habits = try await Habit.query(on: req.db)
            .filter(\.$user.$id == userID)
            .sort(\.$createdAt, .ascending)
            .all()

        return try habits.map { try HabitResponse($0) }
    }

    // MARK: POST /habits
    @Sendable
    func create(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let body = try req.content.decode(CreateHabitRequest.self)
        let name = body.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw Abort(.badRequest, reason: "name is required")
        }

        let habit = Habit(
            userID: userID,
            name: name,
            category: body.category,
            frequency: body.frequency ?? "daily",
            targetTime: body.targetTime,
            description: body.description
        )
        try await habit.save(on: req.db)

        return try await HabitResponse(habit).encodeResponse(status: .created, for: req)
    }

    // MARK: GET /habits/:habitID
    @Sendable
    func show(req: Request) async throws -> HabitResponse {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let habit = try await findHabitOrAbort(req: req, userID: userID)
        return try HabitResponse(habit)
    }

    // MARK: PUT /habits/:habitID
    @Sendable
    func update(req: Request) async throws -> HabitResponse {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let habit = try await findHabitOrAbort(req: req, userID: userID)
        let body = try req.content.decode(UpdateHabitRequest.self)

        if let name = body.name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw Abort(.badRequest, reason: "name cannot be empty") }
            habit.name = trimmed
        }
        if let category = body.category { habit.category = category }
        if let targetTime = body.targetTime { habit.targetTime = targetTime }
        if let description = body.description { habit.description = description }
        if let isActive = body.isActive { habit.isActive = isActive }

        try await habit.update(on: req.db)
        return try HabitResponse(habit)
    }

    // MARK: DELETE /habits/:habitID
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let habit = try await findHabitOrAbort(req: req, userID: userID)
        try await habit.delete(on: req.db)
        return .noContent
    }

    // MARK: POST /habits/:habitID/log
    @Sendable
    func logHabit(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let habit = try await findHabitOrAbort(req: req, userID: userID)
        guard let habitID = habit.id else { throw Abort(.internalServerError) }

        let body = try? req.content.decode(LogHabitRequest.self)
        let log = HabitLog(
            habitID: habitID,
            userID: userID,
            completedAt: body?.completedAt ?? Date(),
            notes: body?.notes
        )
        try await log.save(on: req.db)

        return try await HabitLogResponse(log).encodeResponse(status: .created, for: req)
    }

    // MARK: DELETE /habits/:habitID/log
    @Sendable
    func unlogHabit(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let habit = try await findHabitOrAbort(req: req, userID: userID)
        guard let habitID = habit.id else { throw Abort(.internalServerError) }

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let todayStart = utc.startOfDay(for: Date())
        let tomorrowStart = utc.date(byAdding: .day, value: 1, to: todayStart)!

        guard let log = try await HabitLog.query(on: req.db)
            .filter(\.$habit.$id == habitID)
            .filter(\.$user.$id == userID)
            .filter(\.$completedAt >= todayStart)
            .filter(\.$completedAt < tomorrowStart)
            .sort(\.$completedAt, .descending)
            .first()
        else {
            throw Abort(.notFound, reason: "no log found for today")
        }

        try await log.delete(force: true, on: req.db)
        return .noContent
    }

    // MARK: GET /habits/:habitID/stats
    @Sendable
    func stats(req: Request) async throws -> HabitStatsResponse {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        let habit = try await findHabitOrAbort(req: req, userID: userID)
        guard let habitID = habit.id else { throw Abort(.internalServerError) }

        let logs = try await HabitLog.query(on: req.db)
            .filter(\.$habit.$id == habitID)
            .filter(\.$user.$id == userID)
            .all()

        let habitStats = HabitStatsService.stats(logDates: logs.map { $0.completedAt })
        return HabitStatsResponse(
            habitID: habitID,
            currentStreak: habitStats.currentStreak,
            longestStreak: habitStats.longestStreak,
            completionRate: habitStats.completionRate,
            weekGrid: habitStats.weekGrid
        )
    }

    // MARK: - Private

    private func findHabitOrAbort(req: Request, userID: UUID) async throws -> Habit {
        guard let habitID = req.parameters.get("habitID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "invalid habit ID")
        }
        guard let habit = try await Habit.find(habitID, on: req.db) else {
            throw Abort(.notFound)
        }
        guard habit.$user.id == userID else {
            throw Abort(.forbidden, reason: "Not your habit")
        }
        return habit
    }
}
