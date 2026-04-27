import SwiftUI

struct TodayView: View {

    @Environment(AppRouter.self) private var router
    @State private var viewModel: TodayViewModel

    init(dayKey: String) {
        // ViewModel is initialized with a placeholder router;
        // the real router is injected on onAppear via wireRouter()
        _viewModel = State(wrappedValue: TodayViewModel(dayKey: dayKey, router: AppRouter()))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack(alignment: .bottom) {
            // MARK: Workout scroll area
            ScrollView {
                VStack(spacing: 16) {
                    // TODO: Render workoutSessions and their exercises/sets
                    EmptyStateView(
                        systemImage: "figure.strengthtraining.traditional",
                        title: "No workouts yet",
                        subtitle: "Type a command below to add your first exercise."
                    )
                    .padding(.top, 60)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120) // clearance for input bar
            }

            // MARK: Bottom command input bar
            VStack(spacing: 0) {
                Divider()
                BottomCommandInputBar(
                    text: $viewModel.commandInputText,
                    isProcessing: viewModel.isProcessingCommand,
                    onSubmit: viewModel.submitCommand,
                    onPlusTap: viewModel.openAddWorkoutOrExerciseSheet
                )
            }
            .background(.bar)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: viewModel.openCalendar) {
                    Image(systemName: "calendar")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: viewModel.openSavedExercises) {
                    Image(systemName: "dumbbell")
                }
            }
        }
        .navigationTitle(viewModel.dayKey)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.wireRouter(router)
            viewModel.onAppear()
        }
    }
}
