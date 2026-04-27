import Foundation

@Observable
final class CalendarViewModel {

    var selectedMonth: Date = Date()
    // TODO: var workoutDays: [String: WorkoutDayDTO] = [:]  (dayKey → DTO)

    func selectDay(dayKey: String) {
        // Handled by router in CalendarView
    }

    func advanceMonth() {
        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
    }

    func retreatMonth() {
        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
    }
}
