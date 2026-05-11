import Vapor

// MARK: - Frequency

enum HabitFrequency: String, CaseIterable {
    case daily, weekly, monthly, custom
}

// MARK: - Requests

struct CreateHabitRequest: Content, Sendable {
    let name: String
    let category: String?
    let frequency: String?
    let targetTime: String?
    let description: String?
}

struct UpdateHabitRequest: Content, Sendable {
    let name: String?
    let category: String?
    let targetTime: String?
    let description: String?
    let isActive: Bool?
    let frequency: String?

    init(name: String? = nil, category: String? = nil, targetTime: String? = nil,
         description: String? = nil, isActive: Bool? = nil, frequency: String? = nil) {
        self.name = name
        self.category = category
        self.targetTime = targetTime
        self.description = description
        self.isActive = isActive
        self.frequency = frequency
    }
}

struct LogHabitRequest: Content, Sendable {
    let completedAt: Date?
    let notes: String?
}

// MARK: - Responses

struct HabitResponse: Content, Sendable {
    let id: UUID
    let userID: UUID
    let name: String
    let category: String?
    let frequency: String
    let targetTime: String?
    let description: String?
    let isActive: Bool
    let createdAt: Date?
    let updatedAt: Date?

    init(_ habit: Habit) throws {
        guard let id = habit.id else { throw Abort(.internalServerError) }
        self.id = id
        self.userID = habit.$user.id
        self.name = habit.name
        self.category = habit.category
        self.frequency = habit.frequency
        self.targetTime = habit.targetTime
        self.description = habit.description
        self.isActive = habit.isActive
        self.createdAt = habit.createdAt
        self.updatedAt = habit.updatedAt
    }
}

struct HabitLogResponse: Content, Sendable {
    let id: UUID
    let habitID: UUID
    let userID: UUID
    let completedAt: Date
    let notes: String?
    let createdAt: Date?

    init(_ log: HabitLog) throws {
        guard let id = log.id else { throw Abort(.internalServerError) }
        self.id = id
        self.habitID = log.$habit.id
        self.userID = log.$user.id
        self.completedAt = log.completedAt
        self.notes = log.notes
        self.createdAt = log.createdAt
    }
}

struct HabitStatsResponse: Content, Sendable {
    let habitID: UUID
    let currentStreak: Int
    let longestStreak: Int
    let completionRate: Double
    let weekGrid: [Bool]
}
