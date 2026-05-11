import Vapor
import Fluent

final class CalendarEvent: Model, @unchecked Sendable {
    static let schema = "calendar_events"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "title")
    var title: String

    @OptionalField(key: "notes")
    var notes: String?

    @OptionalField(key: "category")
    var category: String?

    @Field(key: "start_at")
    var startAt: Date

    @Field(key: "end_at")
    var endAt: Date

    @Field(key: "all_day")
    var allDay: Bool

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
        title: String,
        notes: String? = nil,
        category: String? = nil,
        startAt: Date,
        endAt: Date,
        allDay: Bool = false
    ) {
        self.id = id
        self.$user.id = userID
        self.title = title
        self.notes = notes
        self.category = category
        self.startAt = startAt
        self.endAt = endAt
        self.allDay = allDay
    }
}
