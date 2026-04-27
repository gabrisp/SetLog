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
                PlusActionRow(label: "Start New Workout") {
                    viewModel.startNewWorkoutSession()
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
                PlusActionRow(label: "Add Exercise Manually") {
                    // TODO: Open manual exercise entry
                }
            }
        }
        .navigationTitle("Add")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDetents([.medium, .large])
        .onAppear {
            viewModel.wireRouter(router)
            viewModel.load()
        }
    }
}
