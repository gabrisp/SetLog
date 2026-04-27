import SwiftUI

struct MainAppFlowView: View {

    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.mainPath) {
            CalendarView()
                .navigationDestination(for: MainRoute.self) { route in
                    switch route {
                    case .today(let dayKey):
                        TodayView(dayKey: dayKey)
                    }
                }
        }
        .sheet(item: $router.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .onAppear {
            guard !router.hasPerformedInitialTodayRoute else { return }
            router.hasPerformedInitialTodayRoute = true
            // Push without animation so Calendar is never visible on launch
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                router.openToday(dayKey: Date.todayDayKey)
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppSheet) -> some View {
        switch sheet {
        case .settings:
            SettingsFlowView()
                .environment(router)

        case .savedExercises:
            SavedExercisesFlowView()
                .environment(router)

        case .addWorkoutOrExercise(let dayKey):
            AddWorkoutOrExerciseView(dayKey: dayKey)
                .environment(router)

        case .editWorkout, .editExercise, .editSet:
            // TODO: Implement edit sheets
            Text("Edit (coming soon)")

        case .proFeatureGate(let feature):
            ProFeatureGateView(feature: feature)
                .environment(router)
                .presentationDetents([.fraction(0.35), .medium])
        }
    }
}
