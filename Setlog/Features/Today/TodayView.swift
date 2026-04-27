import SwiftUI

struct TodayView: View {

    @Environment(AppRouter.self) private var router
    @State private var viewModel: TodayViewModel

    init(dayKey: String) {
        _viewModel = State(wrappedValue: TodayViewModel(dayKey: dayKey, router: AppRouter()))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: Workout scroll area
            ScrollView {
                VStack(spacing: 16) {
                    // TODO: Render workoutSessions and their exercises/sets
                    Text("No workouts yet for \(viewModel.dayKey)")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120) // clearance for input bar
            }

            // MARK: Bottom command input bar
            VStack(spacing: 0) {
                Divider()
                BottomCommandInputBar(
                    text: Bindable(viewModel).commandInputText,
                    isProcessing: viewModel.isProcessingCommand,
                    onSubmit: viewModel.submitCommand,
                    onPlusTap: viewModel.openAddWorkoutOrExerciseSheet
                )
                .padding(.bottom, 0)
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
        .navigationBarBackButtonHidden(false)
        .onAppear { viewModel.onAppear() }
    }
}
