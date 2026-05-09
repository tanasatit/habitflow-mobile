import Vapor
import Fluent

struct DashboardController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let protected = routes.grouped(JWTAuthenticator(), UserPayload.guardMiddleware())
        protected.get("dashboard", use: dashboard)
    }

    // MARK: GET /dashboard
    @Sendable
    func dashboard(req: Request) async throws -> DashboardResponse {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = payload.userID else { throw Abort(.unauthorized) }

        guard let user = try await User.find(userID, on: req.db) else {
            throw Abort(.unauthorized, reason: "user not found")
        }

        let habits = try await Habit.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$isActive == true)
            .sort(\.$createdAt, .ascending)
            .all()

        // Single bulk fetch to avoid N+1 — 90-day window covers any visible streak.
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let allLogs = try await HabitLog.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$completedAt >= ninetyDaysAgo)
            .all()

        let logsByHabit = Dictionary(grouping: allLogs, by: { $0.$habit.id })

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let todayStart = utc.startOfDay(for: Date())
        let tomorrowStart = utc.date(byAdding: .day, value: 1, to: todayStart)!

        var todayHabits: [TodayHabitItem] = []
        for habit in habits {
            guard let hid = habit.id else { continue }
            let habitLogs = logsByHabit[hid] ?? []
            let habitStats = HabitStatsService.stats(logDates: habitLogs.map { $0.completedAt })
            let completedToday = habitLogs.contains {
                $0.completedAt >= todayStart && $0.completedAt < tomorrowStart
            }
            todayHabits.append(TodayHabitItem(
                habit: try HabitResponse(habit),
                completedToday: completedToday,
                currentStreak: habitStats.currentStreak
            ))
        }

        let overallStreak = todayHabits.map { $0.currentStreak }.max() ?? 0
        let summary = HabitsSummary(
            total: habits.count,
            active: habits.filter { $0.isActive }.count,
            completedToday: todayHabits.filter { $0.completedToday }.count
        )

        return DashboardResponse(
            user: UserSummary(id: userID, name: user.name, role: user.role),
            overallStreak: overallStreak,
            habitsSummary: summary,
            todayHabits: todayHabits
        )
    }
}
