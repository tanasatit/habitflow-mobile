import Vapor
import Fluent

final class HabitLog: Model, @unchecked Sendable {
    static let schema = "habit_logs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "habit_id")
    var habit: Habit

    @Parent(key: "user_id")
    var user: User

    @Field(key: "completed_at")
    var completedAt: Date

    @OptionalField(key: "notes")
    var notes: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        habitID: UUID,
        userID: UUID,
        completedAt: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.$habit.id = habitID
        self.$user.id = userID
        self.completedAt = completedAt
        self.notes = notes
    }
}
