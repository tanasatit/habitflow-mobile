import Vapor
import Fluent

final class Habit: Model, @unchecked Sendable {
    static let schema = "habits"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "name")
    var name: String

    @OptionalField(key: "category")
    var category: String?

    @Field(key: "frequency")
    var frequency: String

    @OptionalField(key: "target_time")
    var targetTime: String?

    @OptionalField(key: "description")
    var description: String?

    @Field(key: "is_active")
    var isActive: Bool

    @Children(for: \.$habit)
    var logs: [HabitLog]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        name: String,
        category: String? = nil,
        frequency: String = "daily",
        targetTime: String? = nil,
        description: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.$user.id = userID
        self.name = name
        self.category = category
        self.frequency = frequency
        self.targetTime = targetTime
        self.description = description
        self.isActive = isActive
    }
}
