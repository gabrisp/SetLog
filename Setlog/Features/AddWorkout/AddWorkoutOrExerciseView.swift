import SwiftUI

struct AddWorkoutOrExerciseView: View {

    @Environment(AppRouter.self) private var router
    @State private var viewModel: AddWorkoutOrExerciseViewModel

    init(dayKey: String) {
        _viewModel = State(wrappedValue: AddWorkoutOrExerciseViewModel(dayKey: dayKey, router: AppRouter()))
    }

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.startNewWorkoutSession()
                } label: {
                    Label("Start New Workout", systemImage: "plus.circle")
                }
            }

            Section("Favorites") {
                // TODO: ForEach viewModel.favorites
                Text("No favorites yet.")
                    .foregroundStyle(.secondary)
            }

            Section("Recent") {
                // TODO: ForEach viewModel.recents
                Text("No recent exercises yet.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    // TODO: Open manual exercise entry
                } label: {
                    Label("Add Exercise Manually", systemImage: "square.and.pencil")
                }
            }
        }
        .navigationTitle("Add")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDetents([.medium, .large])
        .onAppear { viewModel.load() }
    }
}
