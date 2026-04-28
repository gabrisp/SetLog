import SwiftUI

struct TodayView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.appEnvironment) private var environment

    @State private var viewModel: TodayViewModel

    init(dayKey: String) {
        _viewModel = State(wrappedValue: TodayViewModel(dayKey: dayKey, router: AppRouter()))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(viewModel.dayKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                if viewModel.sessionSections.isEmpty {
                    EmptyStateView(
                        systemImage: "figure.strengthtraining.traditional",
                        title: "Log your first set",
                        subtitle: "Type a command below to add your first exercise."
                    )
                    .padding(.top, 32)
                } else {
                    ForEach(viewModel.sessionSections) { sessionSection in
                        sessionCard(sessionSection, viewModel: viewModel)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .top, spacing: 0) {
            TodayTopBar(
                onCalendarTap: viewModel.openCalendar,
                onSavedExercisesTap: viewModel.openSavedExercises
            )
        }
      /*  .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if viewModel.isProcessingCommand,
                   let processingMessage = viewModel.processingMessage {
                    AnimatedProcessingText(text: processingMessage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }

                if let error = viewModel.commandErrorMessage, !error.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                } else if let summary = viewModel.recentCommandSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                BottomCommandInputBar(
                    text: $viewModel.commandInputText,
                    isProcessing: viewModel.isProcessingCommand,
                    onSubmit: viewModel.submitCommand,
                    onPlusTap: viewModel.openAddWorkoutOrExerciseSheet
                )
            }
        }*/
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaBar(edge: .bottom, spacing: 8, content: {
            InputSearchSwiftUI(
                onPlusTap: viewModel.openAddWorkoutOrExerciseSheet,
                onSubmit: { text in viewModel.commandInputText = text; viewModel.submitCommand() }
            )
        })
        .enableWideBackSwipe()
        .onAppear {
            print("[TODAY] appear dayKey=\(viewModel.dayKey) sections=\(viewModel.sessionSections.count)")
            viewModel.wireRouter(router)
            viewModel.wireDependencies(
                workoutRepository: environment.workoutRepository,
                recentItemsRepository: environment.recentItemsRepository,
                commandHistoryRepository: environment.commandHistoryRepository,
                commandInterpreter: environment.commandInterpreter
            )
            viewModel.onAppear()
        }
        .sheet(item: $viewModel.pendingCommandClarification) { clarification in
            CommandClarificationSheet(
                request: clarification.request,
                customText: $viewModel.clarificationCustomText,
                onSelectChoice: viewModel.chooseClarificationOption,
                onSubmitCustom: viewModel.submitClarificationCustomText,
                onDismiss: viewModel.dismissClarificationSheet
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func sessionCard(_ sessionSection: TodayViewModel.SessionSection, viewModel: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(sessionSection.session.title)
                    .font(.headline)
                Spacer()
                Text(sessionSection.session.type.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if sessionSection.exercises.isEmpty {
                Text("No exercises yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessionSection.exercises) { exerciseSection in
                    exerciseCard(exerciseSection, viewModel: viewModel)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    private func exerciseCard(_ exerciseSection: TodayViewModel.ExerciseSection, viewModel: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.tapExercise(id: exerciseSection.exercise.id)
            } label: {
                HStack(spacing: 8) {
                    Text(exerciseSection.exercise.name)
                        .font(.subheadline.weight(.semibold))
                    if let equipment = exerciseSection.exercise.equipment,
                       !equipment.isEmpty {
                        Text(equipment)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if exerciseSection.sets.isEmpty {
                Text("No sets yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(exerciseSection.sets.map(setSummary).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(exerciseSection.sets.enumerated()), id: \.element.id) { index, set in
                    ExerciseSetRow(
                        setNumber: index + 1,
                        reps: Int(set.reps),
                        weight: set.weight,
                        unit: set.unit,
                        onTap: { viewModel.tapSet(id: set.id) }
                    )
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    private func setSummary(_ set: WorkoutSetDTO) -> String {
        let reps = Int(set.reps)
        if set.unit == "bodyweight" {
            return "\(reps) × bodyweight"
        }

        let weightText: String
        if set.weight.rounded() == set.weight {
            weightText = String(Int(set.weight))
        } else {
            weightText = String(format: "%.1f", set.weight)
        }

        return "\(reps) × \(weightText) \(set.unit)"
    }
}
