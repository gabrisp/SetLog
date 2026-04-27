import SwiftUI

struct CalendarView: View {

    @Environment(AppRouter.self) private var router
    @State private var viewModel = CalendarViewModel()

    var body: some View {
        // TODO: Replace with full calendar grid UI
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }
}
