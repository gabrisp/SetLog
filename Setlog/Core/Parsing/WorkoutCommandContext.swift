import Foundation

struct WorkoutCommandContext {
    var dayKey: String
    var selectedWorkoutSessionID: UUID?
    // TODO: var workoutSessions: [WorkoutSessionDTO]
    // TODO: var exercisesInCurrentSession: [ExerciseEntryDTO]
    // TODO: var savedExercises: [SavedExerciseDTO]
    // TODO: var recentSnippets: [RecentWorkoutSnippetDTO]
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
