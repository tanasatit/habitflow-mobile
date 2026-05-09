import Foundation

struct HabitItem: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let category: String
    let description: String?
    let isActive: Bool
}

struct TodayHabitItem: Codable, Sendable, Identifiable {
    let habit: HabitItem
    var completedToday: Bool
    let currentStreak: Int

    var id: String { habit.id }
}

struct HabitsSummary: Codable, Sendable {
    let active: Int
    let total: Int
    let completedToday: Int
}

struct DashboardUser: Codable, Sendable {
    let id: String
    let name: String
    let role: String
}

struct DashboardResponse: Codable, Sendable {
    var todayHabits: [TodayHabitItem]
    let overallStreak: Int
    let habitsSummary: HabitsSummary
    let user: DashboardUser
}

struct HabitLogResponse: Decodable, Sendable {
    let id: String
    let habitID: String
    let userID: String
    let completedAt: Date
}
