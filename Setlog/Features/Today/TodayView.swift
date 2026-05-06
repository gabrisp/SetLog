import SwiftUI

struct TodayView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.appEnvironment) private var environment

    @State private var viewModel: TodayViewModel
    @State private var inputBarHeight: CGFloat = 44
    @State private var showDayWorkoutSheet = false
    @AppStorage("dayDisplayFormat") private var dayDisplayFormat: String = UserDefaultsUserPreferencesService.defaultDayFormat

    @State private var renamingSession: WorkoutSessionDTO? = nil
    @State private var renameTitle: String = ""
    @State private var expandedStateByID: [UUID: Bool] = [:]

    init(dayKey: String) {
        _viewModel = State(wrappedValue: TodayViewModel(dayKey: dayKey, router: AppRouter()))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        let exercises = viewModel.sessionSections.flatMap(\.exercises)

        // Previous scroll block intentionally commented out in favor of TodayScrollView.
        // ScrollView {
        //     VStack(alignment: .leading, spacing: 14) {
        //         VStack(alignment: .leading, spacing: 14) {
        //             if viewModel.sessionSections.isEmpty {
        //                 EmptyStateView(
        //                     systemImage: "figure.strengthtraining.traditional",
        //                     title: "Log your first set",
        //                     subtitle: "Type a command below to add your first exercise."
        //                 )
        //                 .padding(.top, 32)
        //             } else {
        //                 ForEach(viewModel.sessionSections) { section in
        //                     workoutSection(section, viewModel: viewModel)
        //                 }
        //             }
        //         }
        //         .padding(.horizontal, 16)
        //     }
        //     .padding(.top, 8)
        //     .padding(.bottom, 12)
        // }
        TodayScrollView(
            exercises: exercises,
            isEditing: viewModel.isEditingMode,
            expandedStateByID: $expandedStateByID,
            onEditExercise: { exercise in
                viewModel.openExerciseEditor(id: exercise.id)
            },
            onDeleteExercise: { exercise in
                viewModel.requestDeleteExercise(exercise)
            },
            onEditSet: { set in
                viewModel.openSetEditor(id: set.id)
            },
            onDeleteSet: { set in
                viewModel.requestDeleteSet(set)
            },
            onTapSet: { id in
                viewModel.tapSet(id: id)
            }
        )
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .top, spacing: 0) {
            TodayTopBar(
                dayKey: viewModel.dayKey,
                dayDisplayFormat: dayDisplayFormat,
                onCalendarTap: viewModel.openCalendar,
                onDayTap: { showDayWorkoutSheet = true },
                onSavedExercisesTap: viewModel.openSavedExercises
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            Group {
                if !viewModel.isEditingMode {
                    InputSearchBar(
                        text: $viewModel.commandInputText,
                        isProcessing: viewModel.isProcessingCommand,
                        leadingIconName: "dumbbell",
                        onPlusTap: { viewModel.showRecentsSheet = true },
                        onSubmit: viewModel.submitCommand,
                        height: $inputBarHeight
                    )
                    .frame(height: inputBarHeight)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isEditingMode)
        }
        .overlay(alignment: .bottom) {
            floatingFeedback(viewModel: viewModel)
                .padding(.horizontal, 16)
                .padding(.bottom, viewModel.isEditingMode ? 12 : inputBarHeight + 12)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isEditingMode)
        }
        .onAppear {
            viewModel.wireRouter(router)
            viewModel.wireDependencies(
                workoutRepository: environment.workoutRepository,
                exerciseRepository: environment.exerciseRepository,
                exerciseIdentityResolver: environment.exerciseIdentityResolver,
                commandResolutionCache: environment.commandResolutionCache,
                recentItemsRepository: environment.recentItemsRepository,
                commandHistoryRepository: environment.commandHistoryRepository
            )
            viewModel.onAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workoutDataDidChange)) { _ in
            viewModel.load()
        }
        .alert("Rename workout", isPresented: Binding(
            get: { renamingSession != nil },
            set: { if !$0 { renamingSession = nil } }
        )) {
            TextField("Name", text: $renameTitle)
            Button("Save") {
                if let s = renamingSession {
                    viewModel.renameWorkoutSession(id: s.id, title: renameTitle)
                }
                renamingSession = nil
            }
            Button("Cancel", role: .cancel) { renamingSession = nil }
        }
        .sheet(isPresented: $showDayWorkoutSheet) {
            DayWorkoutSheet(dayKey: viewModel.dayKey)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
            get: { viewModel.activeDeleteTarget },
            set: { _ in viewModel.activeDeleteTarget = nil }
        )) { target in
            ReusableDeleteSheet(
                itemName: target.itemName,
                confirmTitle: target.confirmTitle,
                onConfirm: viewModel.performDeleteTarget
            )
            .presentationDetents([.fraction(0.26)])
        }
        .sheet(isPresented: $viewModel.showRecentsSheet) {
            RecentSnippetsSheet(
                snippets: viewModel.recentSnippets,
                templateSnippets: viewModel.templateSnippets,
                savedExercises: viewModel.savedExercises,
                onTapSnippet: viewModel.applyRecentSnippet,
                onTapTemplate: viewModel.applyTemplateSnippet,
                onTapSavedExercise: viewModel.addSavedExerciseQuick,
                onClear: viewModel.clearRecents,
                onOpenSavedExercises: viewModel.openSavedExercises
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showClarificationSheet) {
            AIClarificationSheet(
                intentAnswer: $viewModel.clarificationIntent,
                targetAnswer: $viewModel.clarificationTarget,
                onSubmit: viewModel.submitClarificationAnswers
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func floatingFeedback(viewModel: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let processing = viewModel.processingMessage, viewModel.isProcessingCommand {
                ProcessingBubble(message: processing)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let error = viewModel.floatingErrorText, !error.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
            }

            if let summary = viewModel.floatingInfoText, !summary.isEmpty {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.quaternary.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
            }

            if viewModel.hasUndoAvailable {
                Button {
                    viewModel.undoLastAction()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Undo (\(viewModel.undoSecondsRemaining)s)")
                            .font(.footnote.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.quaternary.opacity(0.95), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .setlogTappable()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity((viewModel.isProcessingCommand || viewModel.floatingErrorText != nil || viewModel.floatingInfoText != nil || viewModel.hasUndoAvailable) ? 1 : 0)
    }

}
