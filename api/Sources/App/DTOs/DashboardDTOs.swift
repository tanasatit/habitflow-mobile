import Vapor

struct DashboardResponse: Content, Sendable {
    let user: UserSummary
    let overallStreak: Int
    let habitsSummary: HabitsSummary
    let todayHabits: [TodayHabitItem]
}

struct UserSummary: Content, Sendable {
    let id: UUID
    let name: String
    let role: UserRole
}

struct HabitsSummary: Content, Sendable {
    let total: Int
    let active: Int
    let completedToday: Int
}

struct TodayHabitItem: Content, Sendable {
    let habit: HabitResponse
    let completedToday: Bool
    let currentStreak: Int
}
