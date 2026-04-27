import SwiftUI

struct ExerciseDetailView: View {

    @State private var viewModel: ExerciseDetailViewModel

    init(exerciseID: UUID) {
        _viewModel = State(wrappedValue: ExerciseDetailViewModel(exerciseID: exerciseID))
    }

    var body: some View {
        List {
            // TODO: exercise image
            // TODO: name, muscles, equipment, description, instructions
            // TODO: favorite snippets section
            // TODO: recent usage section

            Text("Exercise detail coming soon.")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add to Workout", action: viewModel.addToCurrentWorkout)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .onAppear { viewModel.load() }
    }
}
