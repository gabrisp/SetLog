import SwiftUI

struct CalendarView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.appEnvironment) private var environment

    @State private var viewModel = CalendarViewModel()

    private let calendar = Calendar.current

    private var startMonth: Date {
        calendar.date(byAdding: .month, value: -24, to: calendar.startOfMonth(for: Date())) ?? Date()
    }

    private var endMonth: Date {
        calendar.date(byAdding: .month, value: 24, to: calendar.startOfMonth(for: Date())) ?? Date()
    }

    private var initialFocusMonth: Date {
        let components = DateComponents(year: 2026, month: 4, day: 1)
        return calendar.date(from: components) ?? calendar.startOfMonth(for: Date())
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    InfiniteMonthCalendarView(
                        startMonth: startMonth,
                        endMonth: endMonth,
                        isTaken: { date in
                            viewModel.activeDayKeys.contains(date.dayKey)
                        },
                        isDayEnabled: { date in
                            calendar.startOfDay(for: date) <= calendar.startOfDay(for: Date())
                        },
                        onMonthVisible: { monthStart in
                            viewModel.loadMonthIfNeeded(monthStart)
                        }
                    )

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, 0)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                weekdayHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            }
            .safeAreaBar(edge: .top, spacing: 0) {
                CalendarTopBar(
                    onSettingsTap: { router.openSettings() }
                )
                .frame(height: 44)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                viewModel.wire(workoutRepository: environment.workoutRepository)
                scrollToMonth(initialFocusMonth, proxy: proxy, animated: false)
            }
            .onChange(of: router.mainPath) { _, newPath in
                // When returning from Today to Calendar, snap back to initial focus month.
                if newPath.isEmpty {
                    scrollToMonth(initialFocusMonth, proxy: proxy, animated: true)
                }
            }
        }
    }

    private func scrollToMonth(_ month: Date, proxy: ScrollViewProxy, animated: Bool) {
        let targetMonth = calendar.startOfMonth(for: month)

        func scroll() {
            if animated {
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(CalendarMonthScrollID(monthStart: targetMonth), anchor: .top)
                }
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    proxy.scrollTo(CalendarMonthScrollID(monthStart: targetMonth), anchor: .top)
                }
            }
        }

        // Run twice to handle lazy content not fully materialized on first frame.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: scroll)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: scroll)
    }

    private func weekdaySymbolsOrdered() -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        guard symbols.count > 1 else { return symbols }
        guard calendar.firstWeekday > 1 else { return symbols }
        let pivot = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[pivot...]) + Array(symbols[..<pivot])
    }

    private var weekdayHeader: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let columns = Array(repeating: GridItem(.flexible(minimum: 28), spacing: 8), count: 7)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekdaySymbolsOrdered(), id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .background {
            Color.clear
                .glassEffect(.regular.tint(Color.secondary.opacity(0.08)), in: shape)
        }
        .overlay {
            shape
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

@MainActor
private struct InfiniteMonthCalendarView: View {
    let startMonth: Date
    let endMonth: Date
    let isTaken: (Date) -> Bool
    let isDayEnabled: (Date) -> Bool
    let onMonthVisible: (Date) -> Void

    private var calendar: Calendar { .current }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 28, pinnedViews: [.sectionHeaders]) {
            ForEach(monthStarts, id: \.self) { monthStart in
                Section {
                    monthGrid(monthStart)
                        .onAppear {
                            onMonthVisible(monthStart)
                        }
                } header: {
                    monthHeader(monthStart)
                        .id(CalendarMonthScrollID(monthStart: monthStart))
                }
            }
        }
    }

    private var monthStarts: [Date] {
        guard startMonth <= endMonth else { return [startMonth] }
        var values: [Date] = []
        var cursor = calendar.startOfMonth(for: startMonth)
        let last = calendar.startOfMonth(for: endMonth)
        while cursor <= last {
            values.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return values
    }

    @ViewBuilder
    private func monthHeader(_ monthStart: Date) -> some View {
        ZStack {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(monthName(monthStart))
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                Text(yearText(monthStart))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .background(Color(.systemBackground).opacity(0.94))
    }

    @ViewBuilder
    private func monthGrid(_ monthStart: Date) -> some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 28), spacing: 8), count: 7)
        LazyVGrid(columns: columns, spacing: 8) {
            let grid = makeGridDays(for: monthStart)
            ForEach(Array(grid.enumerated()), id: \.offset) { _, date in
                DayCell(
                    date: date,
                    dayKey: date?.dayKey,
                    isTaken: date.map(isTaken) ?? false,
                    isEnabled: date.map(isDayEnabled) ?? false,
                    isToday: date.map(calendar.isDateInToday) ?? false
                )
            }
        }
    }

    private func makeGridDays(for monthStart: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else { return [] }
        guard let daysRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let shift = (firstWeekday - calendar.firstWeekday + 7) % 7

        var values: [Date?] = Array(repeating: nil, count: shift)
        for day in daysRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                values.append(date)
            }
        }
        return values
    }

    private func monthName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale ?? .autoupdatingCurrent
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date).capitalized
    }

    private func yearText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale ?? .autoupdatingCurrent
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
}

private struct DayCell: View {
    let date: Date?
    let dayKey: String?
    let isTaken: Bool
    let isEnabled: Bool
    let isToday: Bool

    private var dayNumber: Int? {
        guard let date else { return nil }
        return Calendar.current.component(.day, from: date)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Group {
            if let dayNumber {
                if let dayKey, isEnabled {
                    NavigationLink(value: MainRoute.today(dayKey: dayKey)) {
                        dayContent(dayNumber: dayNumber, shape: shape)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                } else {
                    dayContent(dayNumber: dayNumber, shape: shape)
                        .opacity(0.7)
                }
            } else {
                Color.clear.frame(height: 40)
            }
        }
    }

    @ViewBuilder
    private func dayContent(dayNumber: Int, shape: RoundedRectangle) -> some View {
        Text("\(dayNumber)")
            .font(.subheadline)
            .foregroundStyle(isTaken ? Color(.systemBackground) : .primary)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background {
                if isTaken {
                    shape.fill(Color.accentColor.opacity(0.92))
                } else {
                    shape.fill(Color.primary.opacity(0.04))
                }
            }
            .overlay(shape.stroke(isToday ? Color.primary.opacity(0.22) : Color.primary.opacity(0.08), lineWidth: isToday ? 2 : 1))
            .overlay {
                if !isTaken, isEnabled {
                    DiagonalSlash()
                        .stroke(Color.primary.opacity(0.22), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                        .padding(10)
                }
            }
    }
}

private struct DiagonalSlash: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

private struct CalendarMonthScrollID: Hashable {
    let monthStart: Date
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
