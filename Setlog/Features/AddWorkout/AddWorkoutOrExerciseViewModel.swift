import Foundation

@Observable
final class AddWorkoutOrExerciseViewModel {

    let dayKey: String
    // TODO: var existingSessions: [WorkoutSessionDTO] = []
    // TODO: var favorites: [FavoriteWorkoutSnippetDTO] = []
    // TODO: var recents: [RecentWorkoutSnippetDTO] = []

    private let router: AppRouter

    init(dayKey: String, router: AppRouter) {
        self.dayKey = dayKey
        self.router = router
    }

    func load() {
        // TODO: Load sessions, favorites, recents
    }

    func startNewWorkoutSession() {
        // TODO: workoutRepository.createWorkoutSession(dayKey:type:title:)
        router.dismissSheet()
    }

    func addFromFavorite(snippetID: UUID) {
        // TODO: exerciseRepository.addFavoriteExerciseToWorkout(...)
        router.dismissSheet()
    }

    func addFromRecent(snippetID: UUID) {
        // TODO: recentItemsRepository-based add
        router.dismissSheet()
    }

    func manualAddExercise(name: String) {
        // TODO: workoutRepository.addExercise(toWorkoutSessionID:name:...)
        router.dismissSheet()
    }
}
