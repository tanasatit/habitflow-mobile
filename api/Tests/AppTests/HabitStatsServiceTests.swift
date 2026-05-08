import XCTest
@testable import App

final class HabitStatsServiceTests: XCTestCase {

    private var utc: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    // Fixed "today" at noon UTC so tests never straddle midnight.
    private lazy var today: Date = {
        var comps = utc.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 12; comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        return utc.date(from: comps)!
    }()

    private func daysAgo(_ n: Int) -> Date {
        utc.date(byAdding: .day, value: -n, to: today)!
    }

    // MARK: - currentStreak

    func testCurrentStreakEmpty() {
        let result = HabitStatsService.stats(logDates: [], today: today)
        XCTAssertEqual(result.currentStreak, 0)
    }

    func testCurrentStreakLoggedToday() {
        let result = HabitStatsService.stats(logDates: [today], today: today)
        XCTAssertEqual(result.currentStreak, 1)
    }

    func testCurrentStreakThreeConsecutiveDays() {
        let result = HabitStatsService.stats(logDates: [daysAgo(0), daysAgo(1), daysAgo(2)], today: today)
        XCTAssertEqual(result.currentStreak, 3)
    }

    func testCurrentStreakPreservedWhenYesterdayLogged() {
        // Not logged today but logged yesterday — streak should stay alive.
        let result = HabitStatsService.stats(logDates: [daysAgo(1), daysAgo(2), daysAgo(3)], today: today)
        XCTAssertEqual(result.currentStreak, 3)
    }

    func testCurrentStreakBrokenByGap() {
        // Logged today and 2 days ago but NOT yesterday → gap breaks streak.
        let result = HabitStatsService.stats(logDates: [daysAgo(0), daysAgo(2)], today: today)
        XCTAssertEqual(result.currentStreak, 1)
    }

    func testCurrentStreakUTCMidnightBoundary() {
        // Log at 23:30 UTC on day D; check streak at 00:30 UTC on day D+1.
        // The log is "yesterday" UTC — streak should be preserved (anchor = yesterday).
        // This guards against timezone-naive boundary comparisons cutting the streak early.
        var comps = DateComponents()
        comps.timeZone = TimeZone(identifier: "UTC")
        comps.year = 2026; comps.month = 5; comps.day = 7
        comps.hour = 23; comps.minute = 30; comps.second = 0
        let logTime = utc.date(from: comps)!

        comps.day = 8; comps.hour = 0; comps.minute = 30
        let checkTime = utc.date(from: comps)!

        let result = HabitStatsService.stats(logDates: [logTime], today: checkTime)
        XCTAssertEqual(result.currentStreak, 1)
    }

    func testCurrentStreakDuplicateLogsCountOnce() {
        // Multiple logs on the same day should count as one day.
        let result = HabitStatsService.stats(
            logDates: [today, today.addingTimeInterval(3600)],
            today: today
        )
        XCTAssertEqual(result.currentStreak, 1)
    }

    // MARK: - longestStreak

    func testLongestStreakEmpty() {
        let result = HabitStatsService.stats(logDates: [], today: today)
        XCTAssertEqual(result.longestStreak, 0)
    }

    func testLongestStreakSingleDay() {
        let result = HabitStatsService.stats(logDates: [today], today: today)
        XCTAssertEqual(result.longestStreak, 1)
    }

    func testLongestStreakPicksLongerRun() {
        // 3-day run, gap, 2-day run → longest = 3.
        let dates = [daysAgo(10), daysAgo(9), daysAgo(8), daysAgo(5), daysAgo(4)]
        let result = HabitStatsService.stats(logDates: dates, today: today)
        XCTAssertEqual(result.longestStreak, 3)
    }

    func testLongestStreakEqualsCurrentWhenUnbroken() {
        let dates = (0..<5).map { daysAgo($0) }
        let result = HabitStatsService.stats(logDates: dates, today: today)
        XCTAssertEqual(result.longestStreak, 5)
        XCTAssertEqual(result.currentStreak, 5)
    }

    // MARK: - weekGrid

    func testWeekGridAllFalseWhenEmpty() {
        let result = HabitStatsService.stats(logDates: [], today: today)
        XCTAssertEqual(result.weekGrid, Array(repeating: false, count: 7))
    }

    func testWeekGridTodayOnly() {
        // index 6 = today, everything else false.
        let result = HabitStatsService.stats(logDates: [today], today: today)
        XCTAssertEqual(result.weekGrid, [false, false, false, false, false, false, true])
    }

    func testWeekGridSparsePattern() {
        // today (idx 6), 2 days ago (idx 4), 5 days ago (idx 1).
        let result = HabitStatsService.stats(
            logDates: [daysAgo(0), daysAgo(2), daysAgo(5)],
            today: today
        )
        XCTAssertEqual(result.weekGrid, [false, true, false, false, true, false, true])
    }

    func testWeekGridIgnoresOlderDates() {
        // A log from 8 days ago is outside the 7-day window.
        let result = HabitStatsService.stats(logDates: [daysAgo(8)], today: today)
        XCTAssertEqual(result.weekGrid, Array(repeating: false, count: 7))
    }

    // MARK: - completionRate

    func testCompletionRateZeroWhenEmpty() {
        let result = HabitStatsService.stats(logDates: [], today: today)
        XCTAssertEqual(result.completionRate, 0.0)
    }

    func testCompletionRatePerfect() {
        let dates = (0..<30).map { daysAgo($0) }
        let result = HabitStatsService.stats(logDates: dates, today: today)
        XCTAssertEqual(result.completionRate, 1.0, accuracy: 0.001)
    }

    func testCompletionRateHalf() {
        // Every other day for 30 days → 15/30.
        let dates = stride(from: 0, to: 30, by: 2).map { daysAgo($0) }
        let result = HabitStatsService.stats(logDates: dates, today: today)
        XCTAssertEqual(result.completionRate, 15.0 / 30.0, accuracy: 0.001)
    }

    func testCompletionRateIgnoresFutureDates() {
        // A log tomorrow should not inflate the 30-day rate.
        let tomorrow = utc.date(byAdding: .day, value: 1, to: today)!
        let result = HabitStatsService.stats(logDates: [tomorrow], today: today)
        XCTAssertEqual(result.completionRate, 0.0)
    }
}
