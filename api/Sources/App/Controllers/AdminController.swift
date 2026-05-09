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
        admin.delete("users", ":userID", use: deleteUser)
    }

    // MARK: GET /admin/users
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

        var todayComps = utc.dateComponents([.year, .month, .day], from: Date())
        todayComps.hour = 8; todayComps.minute = 0; todayComps.second = 0
        todayComps.timeZone = TimeZone(identifier: "UTC")
        let baseDate = utc.date(from: todayComps)!

        for (name, category) in habitDefs {
            let habit = Habit(userID: userID, name: name, category: category, frequency: "daily", targetTime: nil, description: nil)
            try await habit.save(on: req.db)
            guard let habitID = habit.id else { throw Abort(.internalServerError, reason: "habit ID missing after save") }

            for dayOffset in 0..<8 {
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
