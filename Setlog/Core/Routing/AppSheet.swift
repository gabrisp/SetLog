import Foundation

enum AppSheet: Identifiable {
    case settings
    case savedExercises
    case addWorkoutOrExercise(dayKey: String)
    case editWorkout(id: UUID)
    case editExercise(id: UUID)
    case editSet(id: UUID)
    case proFeatureGate(feature: ProFeature)

    var id: String {
        switch self {
        case .settings:                        return "settings"
        case .savedExercises:                  return "savedExercises"
        case .addWorkoutOrExercise(let key):   return "addWorkout-\(key)"
        case .editWorkout(let id):             return "editWorkout-\(id)"
        case .editExercise(let id):            return "editExercise-\(id)"
        case .editSet(let id):                 return "editSet-\(id)"
        case .proFeatureGate(let feature):     return "proGate-\(feature.rawValue)"
        }
    }
}
