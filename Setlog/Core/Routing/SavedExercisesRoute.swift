import Foundation

enum SavedExercisesRoute: Hashable {
    case exerciseDetail(id: UUID)
    case favoriteSnippetDetail(id: UUID)
    case recentSnippetDetail(id: UUID)
}
