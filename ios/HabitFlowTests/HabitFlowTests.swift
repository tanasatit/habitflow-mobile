import Testing
import Foundation
@testable import HabitFlow

// MARK: - CalendarViewModel.weekDays

@Suite("CalendarViewModel.weekDays")
@MainActor
struct WeekDaysTests {
    @Test("returns 7 days")
    func returnsSevenDays() {
        let days = CalendarViewModel.weekDays(containing: Date())
        #expect(days.count == 7)
    }

    @Test("first day is Monday")
    func firstDayIsMonday() {
        let days = CalendarViewModel.weekDays(containing: Date())
        let weekday = Calendar.current.component(.weekday, from: days[0])
        #expect(weekday == 2) // 2 = Monday in Gregorian
    }

    @Test("days are consecutive")
    func daysAreConsecutive() {
        let days = CalendarViewModel.weekDays(containing: Date())
        for i in 1..<days.count {
            let diff = Calendar.current.dateComponents([.day], from: days[i - 1], to: days[i]).day
            #expect(diff == 1)
        }
    }

    @Test("same week regardless of input day")
    func sameWeekForAnyDayInWeek() {
        let cal = Calendar.current
        let monday = CalendarViewModel.weekDays(containing: Date())[0]
        for offset in 0..<7 {
            let day = cal.date(byAdding: .day, value: offset, to: monday)!
            let week = CalendarViewModel.weekDays(containing: day)
            #expect(week[0] == monday)
        }
    }
}

// MARK: - ChatSession

@Suite("ChatSession")
struct ChatSessionTests {
    @Test("title from first user message")
    func titleFromFirstUserMessage() {
        let messages = [
            ChatMessage(role: .user, text: "Help me build a morning routine"),
            ChatMessage(role: .assistant, text: "Sure!")
        ]
        let session = ChatSession(messages: messages)
        #expect(session.title == "Help me build a morning routine")
    }

    @Test("title truncated at 40 chars")
    func titleTruncatedAt40() {
        let long = String(repeating: "a", count: 60)
        let session = ChatSession(messages: [ChatMessage(role: .user, text: long)])
        #expect(session.title.count <= 40)
    }

    @Test("fallback title when no user message")
    func fallbackTitle() {
        let session = ChatSession(messages: [ChatMessage(role: .assistant, text: "Hello!")])
        #expect(session.title == "New conversation")
    }
}

// MARK: - Page decoding

@Suite("Page decoding")
struct PageDecodingTests {
    @Test("decodes items and metadata")
    func decodesPageEnvelope() throws {
        let json = """
        {
          "items": [{"id":"1","name":"Run","category":"fitness","isActive":true}],
          "metadata": {"page":1,"per":20,"total":1}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let page = try decoder.decode(Page<HabitItem>.self, from: json)
        #expect(page.items.count == 1)
        #expect(page.items[0].name == "Run")
        #expect(page.metadata.total == 1)
        #expect(page.metadata.per == 20)
    }

    @Test("empty items array")
    func decodesEmptyItems() throws {
        let json = """
        {"items":[],"metadata":{"page":1,"per":20,"total":0}}
        """.data(using: .utf8)!

        let page = try JSONDecoder().decode(Page<HabitItem>.self, from: json)
        #expect(page.items.isEmpty)
        #expect(page.metadata.total == 0)
    }
}

// MARK: - APIError descriptions

@Suite("APIError")
struct APIErrorTests {
    @Test("forbidden carries server message")
    func forbiddenDescription() {
        let err = APIError.forbidden("Upgrade to premium to create more than 5 habits")
        #expect(err.errorDescription == "Upgrade to premium to create more than 5 habits")
    }

    @Test("unauthorized has fixed message")
    func unauthorizedDescription() {
        #expect(APIError.unauthorized.errorDescription == "Invalid email or password.")
    }

    @Test("server error includes message")
    func serverErrorDescription() {
        let err = APIError.server(500, "Internal error")
        #expect(err.errorDescription == "Internal error")
    }
}
