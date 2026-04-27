import Foundation

enum ProFeature: String, CaseIterable {
    case unlimitedSavedExercises
    case advancedStats
    case unlimitedWorkoutHistory
    case cloudSync
    case customExerciseImages
    case aiCommandParsing

    var displayName: String {
        switch self {
        case .unlimitedSavedExercises: return "Unlimited Saved Exercises"
        case .advancedStats: return "Advanced Stats"
        case .unlimitedWorkoutHistory: return "Unlimited Workout History"
        case .cloudSync: return "iCloud Sync"
        case .customExerciseImages: return "Custom Exercise Images"
        case .aiCommandParsing: return "AI Command Parsing"
        }
    }
}
