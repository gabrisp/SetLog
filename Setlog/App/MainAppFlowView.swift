import SwiftUI

struct MainAppFlowView: View {
    
    @Environment(AppRouter.self) private var router
    @State private var selectedTab: CustomTab = .calendar
    
    var body: some View {
        @Bindable var router = router
        
        NavigationStack(path: $router.mainPath) {
            TabView(selection: $selectedTab) {
                CalendarView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(CustomTab.calendar)
                
                StatsView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(CustomTab.stats)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                    customTabBarView
            }
            .scrollEdgeEffectStyle(.none, for: .bottom)
            .navigationDestination(for: MainRoute.self) { route in
                switch route {
                case .today(let dayKey):
                    TodayView(dayKey: dayKey)
                        .enableNavigationBackSwipeGesture()
                }
            }
        }
        .enableNavigationBackSwipeGesture()
        .onAppear {
            guard !router.hasPerformedInitialTodayRoute else { return }
            router.hasPerformedInitialTodayRoute = true
            selectedTab = .calendar
            
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                router.openToday(dayKey: Date.todayDayKey)
            }
        }
        
        .sheet(item: $router.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
    }
    
    private var customTabBarView: some View {
        HStack(alignment: .bottom) {
            /// Type 1
            CustomTabBar(
                size: .init(width: CGFloat(90 * 2), height: 60),
                barTint: .gray.opacity(0.3),
                activeTab: $selectedTab
            ) { tab in
                Image(systemName: tab.symbol)
                    .font(.system(size: 20, weight: .light))
                    .symbolVariant(.fill)
            }
            .setlogGlass(.regular, in: Capsule())
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity, alignment: .center)

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

        case .editWorkout:
            Text("Edit (coming soon)")

        case .editExercise(let id, let dayKey):
            EditExerciseSheet(exerciseID: id, dayKey: dayKey, onSaved: {})
                .presentationDetents([.large])

        case .editSet(let id, let dayKey):
            EditSetSheet(setID: id, dayKey: dayKey, onSaved: {})
                .presentationDetents([.large])

        case .proFeatureGate(let feature):
            ProFeatureGateView(feature: feature)
                .environment(router)
                .presentationDetents([.fraction(0.35), .medium])
        }
    }
}
