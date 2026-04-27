import Foundation

@Observable
final class AppRouter {

    var mainPath: [MainRoute] = []
    var activeSheet: AppSheet? = nil
    var settingsPath: [SettingsRoute] = []
    var savedExercisesPath: [SavedExercisesRoute] = []

    // Fired once per session — prevents re-pushing Today when Calendar reappears
    var hasPerformedInitialTodayRoute: Bool = false

    // MARK: - Unified navigation

    func go(_ destination: AppDestination) {
        switch destination {
        case .calendar:
            openCalendar()
        case .today(let dayKey):
            openToday(dayKey: dayKey)
        case .settings(let route):
            openSettings(route: route)
        case .savedExercises(let route):
            openSavedExercises(route: route)
        case .addWorkoutOrExercise(let dayKey):
            openAddWorkoutOrExercise(dayKey: dayKey)
        }
    }

    // MARK: - Main stack

    func openToday(dayKey: String) {
        mainPath = [.today(dayKey: dayKey)]
    }

    func openCalendar() {
        mainPath = []
    }

    // MARK: - Sheets

    func openSettings(route: SettingsRoute? = nil) {
        settingsPath = route.map { [$0] } ?? []
        activeSheet = .settings
    }

    func openSavedExercises(route: SavedExercisesRoute? = nil) {
        savedExercisesPath = route.map { [$0] } ?? []
        activeSheet = .savedExercises
    }

    func openAddWorkoutOrExercise(dayKey: String) {
        activeSheet = .addWorkoutOrExercise(dayKey: dayKey)
    }

    func presentProGate(feature: ProFeature) {
        activeSheet = .proFeatureGate(feature: feature)
    }

    func dismissSheet() {
        activeSheet = nil
    }

    func resetSheetNavigation() {
        settingsPath = []
        savedExercisesPath = []
    }
}
