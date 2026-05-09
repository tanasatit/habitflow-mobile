import Foundation

struct CalendarEvent: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let notes: String?
    let startAt: Date
    let endAt: Date
    let allDay: Bool
}

struct CreateEventRequest: Encodable, Sendable {
    let title: String
    let notes: String?
    let startAt: Date
    let endAt: Date
    let allDay: Bool
}
