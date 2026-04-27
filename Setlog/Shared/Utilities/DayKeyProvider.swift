import Foundation

// Stateless utility for generating dayKeys from dates.
// Use Date.todayDayKey or Date.dayKey for most cases.
// This type exists as a seam for future dependency injection (e.g., mocking "today" in tests).
struct DayKeyProvider {

    var today: () -> String = { Date.todayDayKey }

    static let live = DayKeyProvider()
    static let preview = DayKeyProvider(today: { "2026-04-27" })
}
