import Foundation

struct HabitStatsService: Sendable {
    private static let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    static func stats(logDates: [Date], today: Date = Date()) -> HabitStats {
        let days = uniqueDays(from: logDates)
        return HabitStats(
            currentStreak: currentStreak(days: days, today: today),
            longestStreak: longestStreak(days: days),
            completionRate: completionRate(days: days, today: today),
            weekGrid: weekGrid(days: days, today: today)
        )
    }

    // MARK: - Algorithms

    static func uniqueDays(from dates: [Date]) -> Set<DateComponents> {
        Set(dates.map { utcCalendar.dateComponents([.year, .month, .day], from: $0) })
    }

    // Counts consecutive days ending today (if today is logged) or yesterday
    // (if today not yet logged but yesterday was — preserves streak before user logs).
    //
    // All dates are bucketed in UTC, matching completed_at storage and the unique index.
    // Clients in non-UTC timezones should treat the UTC date boundary as the day boundary
    // for streak purposes — a log at 11 PM UTC-8 is stored as the next UTC day.
    static func currentStreak(days: Set<DateComponents>, today: Date) -> Int {
        let todayComps = dayComponents(today)
        let yesterdayComps = dayComponents(offset: -1, from: today)

        let anchor: Date
        if days.contains(todayComps) {
            anchor = today
        } else if days.contains(yesterdayComps) {
            anchor = utcCalendar.date(byAdding: .day, value: -1, to: today)!
        } else {
            return 0
        }

        var streak = 0
        var cursor = anchor
        while days.contains(dayComponents(cursor)) {
            streak += 1
            cursor = utcCalendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }

    static func longestStreak(days: Set<DateComponents>) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.compactMap { noonDate(from: $0) }.sorted()
        guard sorted.count > 1 else { return 1 }
        var longest = 1
        var current = 1
        for i in 1..<sorted.count {
            let diff = utcCalendar.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
            if diff == 1 {
                current += 1
                if current > longest { longest = current }
            } else {
                current = 1
            }
        }
        return longest
    }

    // Fraction of days in the last 30 with at least one log.
    static func completionRate(days: Set<DateComponents>, today: Date) -> Double {
        let window = 30
        var count = 0
        for offset in 0..<window {
            let d = utcCalendar.date(byAdding: .day, value: -offset, to: today)!
            if days.contains(dayComponents(d)) { count += 1 }
        }
        return Double(count) / Double(window)
    }

    // 7-element array: index 0 = 6 days ago, index 6 = today.
    static func weekGrid(days: Set<DateComponents>, today: Date) -> [Bool] {
        (0..<7).map { offset -> Bool in
            let d = utcCalendar.date(byAdding: .day, value: -(6 - offset), to: today)!
            return days.contains(dayComponents(d))
        }
    }

    // MARK: - Helpers

    private static func dayComponents(_ date: Date) -> DateComponents {
        utcCalendar.dateComponents([.year, .month, .day], from: date)
    }

    private static func dayComponents(offset: Int, from date: Date) -> DateComponents {
        let d = utcCalendar.date(byAdding: .day, value: offset, to: date)!
        return dayComponents(d)
    }

    // Rebuilds a Date at noon UTC from year/month/day components for chronological sorting.
    private static func noonDate(from comps: DateComponents) -> Date? {
        var c = comps
        c.hour = 12; c.minute = 0; c.second = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return utcCalendar.date(from: c)
    }
}

struct HabitStats: Sendable {
    let currentStreak: Int
    let longestStreak: Int
    let completionRate: Double
    let weekGrid: [Bool]
}
