import SwiftUI

@MainActor
@Observable
final class CalendarViewModel {
    var events: [CalendarEvent] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func load(weekContaining date: Date, token: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        let (start, end) = weekBounds(for: date)
        do {
            let page: Page<CalendarEvent> = try await api.send(.calendar(start: start, end: end), token: token)
            events = page.items
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = "Failed to load calendar."
        }
    }

    func createEvent(_ request: CreateEventRequest, token: String) async throws {
        let created: CalendarEvent = try await api.send(.createEvent(request), token: token)
        events.append(created)
        events.sort { $0.startAt < $1.startAt }
    }

    func updateEvent(id: String, _ request: UpdateEventRequest, token: String) async throws {
        let updated: CalendarEvent = try await api.send(.updateEvent(id: id, request), token: token)
        if let idx = events.firstIndex(where: { $0.id == id }) {
            events[idx] = updated
        }
        events.sort { $0.startAt < $1.startAt }
    }

    func deleteEvent(id: String, token: String) async {
        do {
            try await api.sendVoid(.deleteEvent(id: id), token: token)
            events.removeAll { $0.id == id }
        } catch {}
    }

    func events(for day: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        return events.filter { cal.isDate($0.startAt, inSameDayAs: day) }
            .sorted { $0.startAt < $1.startAt }
    }

    // Mon–Sun week containing the given date
    static func weekDays(containing date: Date) -> [Date] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let monday = cal.date(from: comps) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    private func weekBounds(for date: Date) -> (Date, Date) {
        let days = Self.weekDays(containing: date)
        let start = days.first ?? date
        let end = Calendar.current.date(byAdding: .day, value: 1, to: days.last ?? date) ?? date
        return (start, end)
    }
}
