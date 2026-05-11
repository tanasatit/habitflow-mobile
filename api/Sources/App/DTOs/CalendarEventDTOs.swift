import Vapor

struct CreateCalendarEventRequest: Content, Sendable {
    let title: String
    let notes: String?
    let category: String?
    let startAt: Date
    let endAt: Date
    let allDay: Bool?
}

struct UpdateCalendarEventRequest: Content, Sendable {
    var title: String? = nil
    var notes: String? = nil
    var category: String? = nil
    var startAt: Date? = nil
    var endAt: Date? = nil
    var allDay: Bool? = nil
}

struct CalendarEventResponse: Content, Sendable {
    let id: UUID
    let userID: UUID
    let title: String
    let notes: String?
    let category: String?
    let startAt: Date
    let endAt: Date
    let allDay: Bool
    let createdAt: Date?
    let updatedAt: Date?

    init(_ event: CalendarEvent) throws {
        guard let id = event.id else { throw Abort(.internalServerError) }
        self.id = id
        self.userID = event.$user.id
        self.title = event.title
        self.notes = event.notes
        self.category = event.category
        self.startAt = event.startAt
        self.endAt = event.endAt
        self.allDay = event.allDay
        self.createdAt = event.createdAt
        self.updatedAt = event.updatedAt
    }
}
