import SwiftUI

struct SavedExercisesView: View {

    @Environment(AppRouter.self) private var router
    @State private var viewModel = SavedExercisesViewModel()

    var body: some View {
        List {
            Section("Saved Exercises") {
                // TODO: ForEach viewModel.exercises
                Text("No saved exercises yet.")
                    .foregroundStyle(.secondary)
            }

            Section("Favorites") {
                // TODO: ForEach viewModel.favorites
                Text("No favorites yet.")
                    .foregroundStyle(.secondary)
            }

            Section("Recent") {
                // TODO: ForEach viewModel.recents
                Text("No recent snippets yet.")
                    .foregroundStyle(.secondary)
            }
        }
        .searchable(text: $viewModel.searchText)
        .navigationTitle("Saved Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.load() }
    }
}
