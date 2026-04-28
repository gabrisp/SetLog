import SwiftUI

struct CalendarView: View {

    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack {
            Text("Calendar")
                .font(.title2.weight(.semibold))

            Spacer()

            Text("Tap a day to open Today")
                .foregroundStyle(.secondary)

            Button("Open Today") {
                router.openToday(dayKey: Date.todayDayKey)
            }
            .padding(.top, 8)

            Spacer()
        }
        .safeAreaBar(edge: .top, spacing: 0) {
            CalendarTopBar(
                onSettingsTap: { router.openSettings() }
            )
            .frame(height: 44)
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableForwardSwipe {
            guard let dayKey = router.lastOpenedDayKey else { return }
            router.openToday(dayKey: dayKey)
        }
    }
}
