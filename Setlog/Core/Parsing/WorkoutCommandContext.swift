import Foundation

struct WorkoutCommandContext {
    var dayKey: String
    var selectedWorkoutSessionID: UUID?
    var workoutSessions: [WorkoutSessionDTO] = []
    var exercisesInCurrentSession: [ExerciseEntryDTO] = []
    var savedExercises: [SavedExerciseDTO] = []
    var recentSnippets: [RecentWorkoutSnippetDTO] = []
    var lastTouchedExerciseID: UUID?
    var lastTouchedSetID: UUID?
    var selectedExerciseID: UUID?
    var preferredWeightUnit: String   // "kg" / "lb"

    static var empty: WorkoutCommandContext {
        WorkoutCommandContext(
            dayKey: Date.todayDayKey,
            preferredWeightUnit: "kg"
        )
    }
}
