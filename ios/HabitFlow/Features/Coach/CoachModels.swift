import Foundation

struct ChatMessage: Identifiable, Sendable {
    let id: UUID
    let role: Role
    let text: String
    let events: [ScheduledEvent]

    enum Role { case user, assistant }

    init(role: Role, text: String, events: [ScheduledEvent] = []) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.events = events
    }
}

struct ScheduledEvent: Decodable, Sendable {
    let title: String
    let startTime: Date
}

struct AIResponse: Decodable, Sendable {
    let reply: String
    let calendarUpdated: Bool
    let events: [ScheduledEvent]?
}
