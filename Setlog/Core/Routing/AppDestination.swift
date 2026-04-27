import Foundation

enum AppDestination {
    case calendar
    case today(dayKey: String)
    case settings(SettingsRoute? = nil)
    case savedExercises(SavedExercisesRoute? = nil)
    case addWorkoutOrExercise(dayKey: String)
}
