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

    @Field(key: "start_at")
    var startAt: Date

    @Field(key: "end_at")
    var endAt: Date

    @Field(key: "all_day")
    var allDay: Bool

    @OptionalField(key: "category")
    var category: String?

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
        startAt: Date,
        endAt: Date,
        allDay: Bool = false,
        category: String? = nil
    ) {
        self.id = id
        self.$user.id = userID
        self.title = title
        self.notes = notes
        self.startAt = startAt
        self.endAt = endAt
        self.allDay = allDay
        self.category = category
    }
}
