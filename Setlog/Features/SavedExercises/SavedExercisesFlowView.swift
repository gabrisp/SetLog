import SwiftUI

struct SavedExercisesFlowView: View {

    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.savedExercisesPath) {
            SavedExercisesView()
                .navigationDestination(for: SavedExercisesRoute.self) { route in
                    switch route {
                    case .exerciseDetail(let id):
                        ExerciseDetailView(exerciseID: id)
                    case .favoriteSnippetDetail(let id):
                        // TODO: FavoriteSnippetDetailView
                        Text("Favorite snippet \(id)")
                    case .recentSnippetDetail(let id):
                        // TODO: RecentSnippetDetailView
                        Text("Recent snippet \(id)")
                    }
                }
        }
    }
}
