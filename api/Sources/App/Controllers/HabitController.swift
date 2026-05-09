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

        if payload.role == .free {
            let activeCount = try await Habit.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$isActive == true)
                .count()
            guard activeCount < 5 else {
                throw Abort(.forbidden, reason: "Upgrade to premium to create more than 5 habits")
            }
        }

        let frequency = try validatedFrequency(body.frequency ?? "daily")
        let habit = Habit(
            userID: userID,
            name: name,
            category: body.category,
            frequency: frequency,
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
        if let frequency = body.frequency {
            habit.frequency = try validatedFrequency(frequency)
        }

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
        let logDate = body?.completedAt ?? Date()

        // All day boundaries use UTC so they stay consistent with the unique index
        // (completed_at::date) and the streak-calculation calendar in HabitStatsService.
        let (dayStart, dayEnd) = utcDayBounds(for: logDate)

        let existing = try await HabitLog.query(on: req.db)
            .filter(\.$habit.$id == habitID)
            .filter(\.$user.$id == userID)
            .filter(\.$completedAt >= dayStart)
            .filter(\.$completedAt < dayEnd)
            .first()
        guard existing == nil else {
            throw Abort(.conflict, reason: "already logged for this day")
        }

        let log = HabitLog(habitID: habitID, userID: userID, completedAt: logDate, notes: body?.notes)
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

    private func validatedFrequency(_ raw: String) throws -> String {
        guard HabitFrequency(rawValue: raw) != nil else {
            let valid = HabitFrequency.allCases.map(\.rawValue).joined(separator: ", ")
            throw Abort(.badRequest, reason: "invalid frequency — valid values: \(valid)")
        }
        return raw
    }

    private func utcDayBounds(for date: Date = Date()) -> (start: Date, end: Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.startOfDay(for: date)
        return (start, cal.date(byAdding: .day, value: 1, to: start)!)
    }

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
