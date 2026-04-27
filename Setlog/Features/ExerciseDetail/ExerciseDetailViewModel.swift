import Foundation

@Observable
final class ExerciseDetailViewModel {

    let exerciseID: UUID
    // TODO: var exercise: SavedExerciseDTO? = nil
    // TODO: var favoriteSnippets: [FavoriteWorkoutSnippetDTO] = []
    // TODO: var recentUsage: [RecentWorkoutSnippetDTO] = []

    init(exerciseID: UUID) {
        self.exerciseID = exerciseID
    }

    func load() {
        // TODO: exerciseRepository.fetchSavedExercise(id: exerciseID)
        // TODO: exerciseRepository.fetchFavoriteSnippets() filtered by exerciseID
    }

    func addToCurrentWorkout() {
        // TODO: Route to TodayViewModel.addExerciseFromFavorite
    }
}
