import Foundation

@Observable
final class SavedExercisesViewModel {

    var searchText: String = ""
    // TODO: var exercises: [SavedExerciseDTO] = []
    // TODO: var favorites: [FavoriteWorkoutSnippetDTO] = []
    // TODO: var recents: [RecentWorkoutSnippetDTO] = []

    func load() {
        // TODO: exerciseRepository.fetchSavedExercises()
        // TODO: exerciseRepository.fetchFavoriteSnippets()
        // TODO: recentItemsRepository.fetchRecentSnippets(limit: 20)
    }

    func addToWorkout(exerciseID: UUID) {
        // TODO: Route to TodayViewModel.addExerciseFromFavorite
    }
}
