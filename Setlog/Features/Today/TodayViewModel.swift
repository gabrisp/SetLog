import Foundation

@Observable
final class TodayViewModel {

    let dayKey: String
    let date: Date

    // TODO: var workoutSessions: [WorkoutSessionDTO] = []
    var selectedWorkoutSessionID: UUID? = nil

    // TODO: var exercises: [ExerciseEntryDTO] = []
    var lastTouchedExerciseID: UUID? = nil
    var lastTouchedSetID: UUID? = nil

    var commandInputText: String = ""
    var isProcessingCommand: Bool = false

    // TODO: var pendingConfirmation: CommandConfirmationRequest? = nil

    private let router: AppRouter

    init(dayKey: String, router: AppRouter) {
        self.dayKey = dayKey
        self.date = Date.date(fromDayKey: dayKey) ?? Date()
        self.router = router
    }

    // MARK: - Lifecycle

    func onAppear() {
        load()
    }

    func load() {
        // TODO: Fetch WorkoutDay + sessions via workoutRepository
    }

    // MARK: - Navigation

    func openCalendar() {
        router.openCalendar()
    }

    func openSavedExercises() {
        router.openSavedExercises()
    }

    func openAddWorkoutOrExerciseSheet() {
        router.openAddWorkoutOrExercise(dayKey: dayKey)
    }

    // MARK: - Command input

    func submitCommand() {
        guard !commandInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let raw = commandInputText
        commandInputText = ""
        isProcessingCommand = true
        // TODO: Pass raw to WorkoutCommandInterpreter
        //       Execute the resulting plan via workoutRepository
        //       Save CommandHistoryItem + RecentWorkoutSnippet
        isProcessingCommand = false
    }

    // MARK: - Workout actions

    func addNewWorkoutSession() {
        // TODO: workoutRepository.createWorkoutSession(dayKey:type:title:)
    }

    func tapExercise(id: UUID) {
        lastTouchedExerciseID = id
    }

    func tapSet(id: UUID) {
        lastTouchedSetID = id
    }

    func duplicateSet(id: UUID) {
        // TODO: workoutRepository.duplicateSet(id:modifier:)
    }

    func deleteSet(id: UUID) {
        // TODO: workoutRepository.deleteSet(id:)
    }

    func addSetToExercise(exerciseID: UUID) {
        // TODO: workoutRepository.addSet(toExerciseEntryID:set:)
    }

    func addExerciseFromFavorite(snippetID: UUID) {
        // TODO: exerciseRepository.addFavoriteExerciseToWorkout(...)
    }

    func addRecentSnippet(snippetID: UUID) {
        // TODO: recentItemsRepository-based add
    }
}
