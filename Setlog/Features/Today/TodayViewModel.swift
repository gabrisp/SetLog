import Foundation
import SwiftUI

@MainActor
@Observable
final class TodayViewModel {

    struct ExerciseSection: Identifiable {
        let exercise: ExerciseEntryDTO
        let sets: [WorkoutSetDTO]

        var id: UUID { exercise.id }
    }

    struct SessionSection: Identifiable {
        let session: WorkoutSessionDTO
        let exercises: [ExerciseSection]

        var id: UUID { session.id }
    }

    enum DeleteTarget: Identifiable {
        case workout(WorkoutSessionDTO)
        case exercise(ExerciseEntryDTO)
        case set(WorkoutSetDTO)

        var id: String {
            switch self {
            case .workout(let item): return "workout-\(item.id)"
            case .exercise(let item): return "exercise-\(item.id)"
            case .set(let item): return "set-\(item.id)"
            }
        }

        var itemName: String {
            switch self {
            case .workout(let item):
                return item.title.isEmpty ? "workout" : item.title
            case .exercise(let item):
                return item.name
            case .set:
                return "set"
            }
        }

        var confirmTitle: String {
            switch self {
            case .workout:
                return "Delete Workout"
            case .exercise:
                return "Delete Exercise"
            case .set:
                return "Delete Set"
            }
        }
    }

    private enum UndoAction {
        case addedExercise(exerciseID: UUID)
        case addedSets(setIDs: [UUID])
        case removedSet(set: WorkoutSetDTO)
        case modifiedSet(original: WorkoutSetDTO)
        case repeatedExercise(exerciseID: UUID)
    }

    let dayKey: String
    let date: Date

    var sessionSections: [SessionSection] = []
    var selectedWorkoutSessionID: UUID? = nil

    var lastTouchedExerciseID: UUID? = nil
    var lastTouchedSetID: UUID? = nil

    var commandInputText: String = ""
    var isProcessingCommand: Bool = false
    var processingMessage: String? = nil
    var commandErrorMessage: String? = nil
    var recentCommandSummary: String? = nil

    var isEditingMode: Bool = false
    var floatingInfoText: String? = nil
    var floatingErrorText: String? = nil
    var expandedWorkoutIDs: Set<UUID> = []
    var expandedExerciseIDs: Set<UUID> = []
    var collapsedExerciseIDs: Set<UUID> = []

    var undoSecondsRemaining: Int = 0
    var hasUndoAvailable: Bool {
        pendingUndoAction != nil && undoSecondsRemaining > 0
    }

    var recentSnippets: [RecentWorkoutSnippetDTO] = []
    var templateSnippets: [FavoriteWorkoutSnippetDTO] = []
    var savedExercises: [SavedExerciseDTO] = []

    var activeDeleteTarget: DeleteTarget? = nil

    var showRecentsSheet: Bool = false
    var showClarificationSheet: Bool = false
    var clarificationIntent: String = ""
    var clarificationTarget: String = ""

    let processingMessages: [String] = [
        "Analyzing command...",
        "Understanding the exercise...",
        "Checking workout context...",
        "Reading sets and weights...",
        "Applying command...",
        "Saving workout changes...",
        "Almost done...",
    ]

    private var router: AppRouter
    private var workoutRepository: WorkoutRepositoryProtocol?
    private var exerciseRepository: ExerciseRepositoryProtocol?
    private var exerciseIdentityResolver: ExerciseIdentityResolver?
    private var commandResolutionCache: CommandResolutionCache?
    private var recentItemsRepository: RecentItemsRepositoryProtocol?
    private var commandHistoryRepository: CommandHistoryRepositoryProtocol?

    private var processingMessageTask: Task<Void, Never>?
    private var processingCommandTask: Task<Void, Never>?
    private var undoCountdownTask: Task<Void, Never>?

    private var pendingCancelInputText: String = ""
    private var pendingUndoAction: UndoAction? = nil
    private var pendingClarificationRawCommand: String? = nil

    init(dayKey: String, router: AppRouter) {
        self.dayKey = dayKey
        self.date = Date.date(fromDayKey: dayKey) ?? Date()
        self.router = router
    }

    func wireRouter(_ router: AppRouter) {
        self.router = router
    }

    func wireDependencies(
        workoutRepository: WorkoutRepositoryProtocol,
        exerciseRepository: ExerciseRepositoryProtocol,
        exerciseIdentityResolver: ExerciseIdentityResolver,
        commandResolutionCache: CommandResolutionCache,
        recentItemsRepository: RecentItemsRepositoryProtocol,
        commandHistoryRepository: CommandHistoryRepositoryProtocol
    ) {
        self.workoutRepository = workoutRepository
        self.exerciseRepository = exerciseRepository
        self.exerciseIdentityResolver = exerciseIdentityResolver
        self.commandResolutionCache = commandResolutionCache
        self.recentItemsRepository = recentItemsRepository
        self.commandHistoryRepository = commandHistoryRepository
    }

    // MARK: - Lifecycle

    func onAppear() {
        load()
    }

    func load() {
        Task {
            await loadSectionsAndRecents()
        }
    }

    // MARK: - Navigation

    func openCalendar() {
        router.openCalendar()
    }

    func openSavedExercises() {
        router.openSavedExercises()
    }

    func openAddWorkoutOrExerciseSheet() {
        router.openAddWorkoutOrExercise(dayKey: dayKey)
    }

    func toggleEditMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingMode.toggle()
        }
    }

    func cancelEditMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingMode = false
        }
    }

    func confirmEditMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingMode = false
        }
    }

    // MARK: - Accordion UI state

    func isWorkoutExpanded(_ id: UUID) -> Bool {
        expandedWorkoutIDs.contains(id)
    }

    func toggleWorkoutExpanded(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedWorkoutIDs.contains(id) {
                expandedWorkoutIDs.remove(id)
            } else {
                expandedWorkoutIDs.insert(id)
            }
        }
    }

    func setWorkoutExpanded(_ id: UUID, isExpanded: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if isExpanded {
                expandedWorkoutIDs.insert(id)
            } else {
                expandedWorkoutIDs.remove(id)
            }
        }
    }

    func isExerciseExpanded(_ id: UUID) -> Bool {
        expandedExerciseIDs.contains(id)
    }

    func toggleExerciseExpanded(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedExerciseIDs.contains(id) {
                expandedExerciseIDs.remove(id)
            } else {
                expandedExerciseIDs.insert(id)
            }
        }
    }

    func setExerciseExpanded(_ id: UUID, isExpanded: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if isExpanded {
                expandedExerciseIDs.insert(id)
            } else {
                expandedExerciseIDs.remove(id)
            }
        }
    }

    func isExerciseOpenByDefault(_ id: UUID) -> Bool {
        !collapsedExerciseIDs.contains(id)
    }

    func setExerciseOpenByDefault(_ id: UUID, isOpen: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if isOpen {
                collapsedExerciseIDs.remove(id)
            } else {
                collapsedExerciseIDs.insert(id)
            }
        }
    }

    // MARK: - Command input

    func submitCommand() {
        let trimmed = commandInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[AI DEBUG] submitCommand() raw='\(commandInputText)' trimmed='\(trimmed)' processing=\(isProcessingCommand)")
        guard !trimmed.isEmpty, !isProcessingCommand else {
            if isProcessingCommand { cancelCurrentCommand() }
            return
        }
        floatingErrorText = nil
        pendingCancelInputText = trimmed
        processingCommandTask = Task {
            await submitCommandInternal(rawText: trimmed, isClarificationRetry: false)
        }
    }

    func submitClarificationAnswers() {
        guard let raw = pendingClarificationRawCommand else { return }

        let intent = clarificationIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = clarificationTarget.trimmingCharacters(in: .whitespacesAndNewlines)

        var extra: [String] = []
        if !intent.isEmpty { extra.append("Intent: \(intent)") }
        if !target.isEmpty { extra.append("Target: \(target)") }

        let merged = extra.isEmpty
            ? raw
            : "\(raw)\nClarification:\n- \(extra.joined(separator: "\n- "))"

        clarificationIntent = ""
        clarificationTarget = ""
        pendingClarificationRawCommand = nil

        processingCommandTask = Task {
            await submitCommandInternal(rawText: merged, isClarificationRetry: true)
        }
    }

    func cancelCurrentCommand() {
        processingCommandTask?.cancel()
        processingCommandTask = nil
        stopProcessingMessages()
        isProcessingCommand = false
        commandErrorMessage = nil
        commandInputText = pendingCancelInputText
    }

    func startProcessingMessages() {
        processingMessageTask?.cancel()
        processingMessage = processingMessages.first

        processingMessageTask = Task { [weak self] in
            guard let self else { return }
            var index = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                index = (index + 1) % self.processingMessages.count
                self.processingMessage = self.processingMessages[index]
            }
        }
    }

    func stopProcessingMessages() {
        processingMessageTask?.cancel()
        processingMessageTask = nil
        processingMessage = nil
    }

    // MARK: - Workout actions

    func addNewWorkoutSession() {
        Task {
            guard let workoutRepository else { return }
            do {
                let session = try await workoutRepository.createWorkoutSession(dayKey: dayKey, type: "strength", title: "Workout")
                selectedWorkoutSessionID = session.id
                await loadSectionsAndRecents()
            } catch {
                commandErrorMessage = error.localizedDescription
                withAnimation(.easeInOut(duration: 0.2)) {
                    floatingErrorText = error.localizedDescription
                }
            }
        }
    }

    func tapExercise(id: UUID) {
        lastTouchedExerciseID = id
        if isEditingMode {
            router.openEditExercise(id: id, dayKey: dayKey)
        }
    }

    func openExerciseEditor(id: UUID) {
        lastTouchedExerciseID = id
        router.openEditExercise(id: id, dayKey: dayKey)
    }

    func renameWorkoutSession(id: UUID, title: String) {
        Task {
            guard let workoutRepository else { return }
            do {
                try await workoutRepository.updateWorkoutSession(id: id, title: title)
                await loadSectionsAndRecents()
            } catch {
                commandErrorMessage = error.localizedDescription
                withAnimation(.easeInOut(duration: 0.2)) {
                    floatingErrorText = error.localizedDescription
                }
            }
        }
    }

    func addManualExercise(toSessionID: UUID, name: String, equipment: String?) {
        Task {
            guard let workoutRepository, let exerciseIdentityResolver else { return }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            do {
                let eq = equipment?.trimmingCharacters(in: .whitespacesAndNewlines)
                let identity = try await exerciseIdentityResolver.resolve(
                    rawInput: trimmed,
                    hintedExerciseName: trimmed,
                    hintedEquipment: eq
                )
                let entry = try await workoutRepository.addExercise(
                    toWorkoutSessionID: toSessionID,
                    name: identity.canonicalName,
                    equipment: identity.equipment ?? (eq?.isEmpty == false ? eq : nil),
                    savedExerciseID: identity.savedExerciseID,
                    isUnilateral: false
                )
                try await workoutRepository.updateExercise(
                    id: entry.id,
                    name: nil,
                    equipment: identity.equipment ?? (eq?.isEmpty == false ? eq : nil),
                    notes: nil,
                    isUnilateral: nil,
                    primaryMusclesText: identity.primaryMusclesText,
                    secondaryMusclesText: identity.secondaryMusclesText
                )
                lastTouchedExerciseID = entry.id
                await loadSectionsAndRecents()
            } catch {
                commandErrorMessage = error.localizedDescription
                withAnimation(.easeInOut(duration: 0.2)) {
                    floatingErrorText = error.localizedDescription
                }
            }
        }
    }

    func tapSet(id: UUID) {
        lastTouchedSetID = id
        if isEditingMode {
            router.openEditSet(id: id, dayKey: dayKey)
        }
    }

    func openSetEditor(id: UUID) {
        lastTouchedSetID = id
        router.openEditSet(id: id, dayKey: dayKey)
    }

    func requestDeleteExercise(_ exercise: ExerciseEntryDTO) {
        activeDeleteTarget = .exercise(exercise)
    }

    func requestDeleteWorkout(_ workout: WorkoutSessionDTO) {
        activeDeleteTarget = .workout(workout)
    }

    func requestDeleteSet(_ set: WorkoutSetDTO) {
        activeDeleteTarget = .set(set)
    }

    func performDeleteTarget() {
        guard let target = activeDeleteTarget else { return }
        activeDeleteTarget = nil

        switch target {
        case .workout(let session):
            deleteWorkoutSession(id: session.id)
        case .exercise(let exercise):
            deleteExercise(id: exercise.id)
        case .set(let set):
            deleteSet(id: set.id)
        }
    }

    func deleteExercise(id: UUID) {
        Task {
            guard let workoutRepository else { return }
            do {
                try await workoutRepository.deleteExercise(id: id)
                if lastTouchedExerciseID == id { lastTouchedExerciseID = nil }
                await loadSectionsAndRecents()
            } catch {
                commandErrorMessage = error.localizedDescription
                withAnimation(.easeInOut(duration: 0.2)) {
                    floatingErrorText = error.localizedDescription
                }
            }
        }
    }

    func deleteWorkoutSession(id: UUID) {
        Task {
            guard let workoutRepository else { return }
            do {
                try await workoutRepository.deleteWorkoutSession(id: id)
                if selectedWorkoutSessionID == id { selectedWorkoutSessionID = nil }
                await loadSectionsAndRecents()
            } catch {
                commandErrorMessage = error.localizedDescription
                withAnimation(.easeInOut(duration: 0.2)) {
                    floatingErrorText = error.localizedDescription
                }
            }
        }
    }

    func duplicateSet(id: UUID) {
        Task {
            guard let workoutRepository else { return }
            do {
                let duplicated = try await workoutRepository.duplicateSet(id: id, modifier: nil)
                lastTouchedSetID = duplicated.id
                lastTouchedExerciseID = duplicated.exerciseEntryID
                await loadSectionsAndRecents()
            } catch {
                commandErrorMessage = error.localizedDescription
                withAnimation(.easeInOut(duration: 0.2)) {
                    floatingErrorText = error.localizedDescription
                }
            }
        }
    }

    func deleteSet(id: UUID) {
        Task {
            guard let workoutRepository else { return }
            do {
                try await workoutRepository.deleteSet(id: id)
                lastTouchedSetID = nil
                await loadSectionsAndRecents()
            } catch {
                commandErrorMessage = error.localizedDescription
                withAnimation(.easeInOut(duration: 0.2)) {
                    floatingErrorText = error.localizedDescription
                }
            }
        }
    }

    func addSetToExercise(exerciseID: UUID) {
        Task {
            guard let workoutRepository else { return }
            do {
                let set = try await workoutRepository.addSet(
                    toExerciseEntryID: exerciseID,
                    reps: 8,
                    weight: 0,
                    unit: "kg",
                    side: nil
                )
                lastTouchedSetID = set.id
                lastTouchedExerciseID = exerciseID
                await loadSectionsAndRecents()
            } catch {
                commandErrorMessage = error.localizedDescription
                withAnimation(.easeInOut(duration: 0.2)) {
                    floatingErrorText = error.localizedDescription
                }
            }
        }
    }

    func addExerciseFromFavorite(snippetID: UUID) {
        _ = snippetID
        // TODO: exerciseRepository.addFavoriteExerciseToWorkout(...)
    }

    func addRecentSnippet(snippetID: UUID) {
        _ = snippetID
        // TODO: repository-based apply recent command payload
    }

    func applyRecentSnippet(_ snippet: RecentWorkoutSnippetDTO) {
        commandInputText = snippet.title
        showRecentsSheet = false
    }

    func clearRecents() {
        Task {
            guard let recentItemsRepository else { return }
            do {
                try await recentItemsRepository.clearRecents()
                recentSnippets = []
            } catch {
                floatingErrorText = error.localizedDescription
            }
        }
    }

    // MARK: - Undo

    func undoLastAction() {
        guard let pendingUndoAction, undoSecondsRemaining > 0 else { return }
        guard let workoutRepository else { return }

        undoCountdownTask?.cancel()
        undoCountdownTask = nil

        Task {
            do {
                try await applyUndoAction(pendingUndoAction, workoutRepository: workoutRepository)
                self.pendingUndoAction = nil
                self.undoSecondsRemaining = 0
                self.floatingInfoText = "Last action reverted"
                await loadSectionsAndRecents()
            } catch {
                self.floatingErrorText = error.localizedDescription
            }
        }
    }

    private func setUndoAction(_ action: UndoAction?) {
        pendingUndoAction = action
        undoCountdownTask?.cancel()

        guard action != nil else {
            undoSecondsRemaining = 0
            return
        }

        undoSecondsRemaining = 10
        undoCountdownTask = Task { [weak self] in
            guard let self else { return }
            while self.undoSecondsRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.undoSecondsRemaining -= 1
            }
            if self.undoSecondsRemaining <= 0 {
                self.pendingUndoAction = nil
            }
        }
    }

    private func applyUndoAction(_ action: UndoAction, workoutRepository: WorkoutRepositoryProtocol) async throws {
        switch action {
        case .addedExercise(let exerciseID):
            try await workoutRepository.deleteExercise(id: exerciseID)

        case .addedSets(let setIDs):
            for id in setIDs {
                try await workoutRepository.deleteSet(id: id)
            }

        case .removedSet(let set):
            _ = try await workoutRepository.addSet(toExerciseEntryID: set.exerciseEntryID, set: set)

        case .modifiedSet(let original):
            try await workoutRepository.updateSet(
                id: original.id,
                reps: original.reps,
                weight: original.weight,
                unit: original.unit,
                notes: original.notes,
                side: original.side
            )

        case .repeatedExercise(let exerciseID):
            try await workoutRepository.deleteExercise(id: exerciseID)
        }
    }

    // MARK: - Internal command execution

    private func submitCommandInternal(rawText: String, isClarificationRetry: Bool) async {
        print("[AI DEBUG] submitCommandInternal() start rawText='\(rawText)'")
        guard let workoutRepository else {
            commandErrorMessage = "Today dependencies are not available yet."
            print("[AI DEBUG] submitCommandInternal() ERROR: workoutRepository nil")
            return
        }

        isProcessingCommand = true
        startProcessingMessages()
        commandErrorMessage = nil
        recentCommandSummary = nil
        floatingErrorText = nil

        var executionSucceeded = false
        var summaryForHistory = ""
        var actionForHistory: String? = nil

        defer {
            stopProcessingMessages()
            isProcessingCommand = false
        }

        do {
            let context = try await buildAIContext(workoutRepository: workoutRepository)
            print("[AI DEBUG] context lastExercise=\(context.lastExercise ?? "nil") lastSets=\(context.lastSets.map(String.init) ?? "nil")")
            let result = try await AICommandService.shared.interpret(command: rawText, context: context)
            actionForHistory = result.action.rawValue

            let execution = try await executeAI(result: result, workoutRepository: workoutRepository)
            summaryForHistory = execution.summary
            executionSucceeded = true
            commandInputText = ""
            recentCommandSummary = summaryForHistory
            withAnimation(.easeInOut(duration: 0.2)) {
                floatingInfoText = summaryForHistory
            }

            if execution.exercisesAdded > 0 {
                try await AIUsageService.shared.recordUsage(
                    inputTokens: 0,
                    outputTokens: 0,
                    exercisesAdded: execution.exercisesAdded
                )
            }

            setUndoAction(execution.undoAction)
            await learnCommandResolutionIfNeeded(rawText: rawText, result: result)

            await saveRecentSnippetIfNeeded(summaryForHistory)
            await loadSectionsAndRecents()
        } catch let aiError as AIUsageError {
            print("[AI DEBUG] submitCommandInternal() AIUsageError: \(aiError.localizedDescription)")
            commandErrorMessage = aiError.localizedDescription
            withAnimation(.easeInOut(duration: 0.2)) {
                floatingErrorText = aiError.localizedDescription
            }
        } catch {
            print("[AI DEBUG] submitCommandInternal() CATCH: \(error.localizedDescription)")
            commandErrorMessage = error.localizedDescription
            withAnimation(.easeInOut(duration: 0.2)) {
                floatingErrorText = error.localizedDescription
            }
        }

        await saveCommandHistory(rawText: rawText, commandType: actionForHistory, success: executionSucceeded)
    }

    private func executeAI(
        result: WorkoutCommandResult,
        workoutRepository: WorkoutRepositoryProtocol
    ) async throws -> (summary: String, exercisesAdded: Int, undoAction: UndoAction?) {
        switch result.action {
        case .addExercise:
            return try await applyAddExercise(result: result, workoutRepository: workoutRepository)
        case .addSets:
            return try await applyAddSets(result: result, workoutRepository: workoutRepository)
        case .removeLastSet:
            return try await applyRemoveLastSet(workoutRepository: workoutRepository)
        case .modifyLastSet:
            return try await applyModifyLastSet(result: result, workoutRepository: workoutRepository)
        case .repeatLastExercise:
            return try await applyRepeatLastExercise(result: result, workoutRepository: workoutRepository)
        }
    }

    private func applyAddExercise(
        result: WorkoutCommandResult,
        workoutRepository: WorkoutRepositoryProtocol
    ) async throws -> (summary: String, exercisesAdded: Int, undoAction: UndoAction?) {
        guard let exerciseIdentityResolver else {
            throw TodayCommandError.validation("Exercise identity resolver is not available.")
        }
        let session = try await resolveActiveSession(workoutRepository: workoutRepository)

        guard let rawName = result.exercise?.trimmingCharacters(in: .whitespacesAndNewlines), !rawName.isEmpty else {
            throw TodayCommandError.validation("I couldn’t understand that command. Try writing it another way.")
        }

        let identity = try await exerciseIdentityResolver.resolve(
            rawInput: rawName,
            hintedExerciseName: rawName,
            hintedEquipment: result.equipment
        )

        let exercisesInSession = try await workoutRepository.fetchExercises(workoutSessionID: session.id)
        if let existing = findSessionExercise(
            exercises: exercisesInSession,
            matchingSavedExerciseID: identity.savedExerciseID,
            equipmentHint: result.equipment ?? identity.equipment
        ) {
            lastTouchedExerciseID = existing.id
            let setResult = try await applyAddSets(
                result: result,
                workoutRepository: workoutRepository
            )
            return (
                setResult.summary,
                setResult.exercisesAdded,
                setResult.undoAction
            )
        }

        let created = try await workoutRepository.addExercise(
            toWorkoutSessionID: session.id,
            name: identity.canonicalName,
            equipment: result.equipment ?? identity.equipment,
            savedExerciseID: identity.savedExerciseID,
            isUnilateral: result.modifiers.contains("unilateral")
        )

        try await workoutRepository.updateExercise(
            id: created.id,
            name: nil,
            equipment: result.equipment ?? identity.equipment,
            notes: nil,
            isUnilateral: nil,
            primaryMusclesText: identity.primaryMusclesText,
            secondaryMusclesText: identity.secondaryMusclesText
        )

        lastTouchedExerciseID = created.id

        if result.sets != nil || result.reps != nil || result.weight != nil || result.weightDelta != nil {
            let semantics = parseSetSemantics(from: result)
            let count = max(1, result.sets ?? 1)
            let reps = Int16(max(0, result.reps ?? 0))
            let suggestedWeight = try await suggestedWeightForExercise(
                normalizedName: normalize(identity.canonicalName),
                in: session.id,
                workoutRepository: workoutRepository
            )
            let baseWeight = result.weight ?? suggestedWeight ?? 0
            let weightValue = max(0, baseWeight + (result.weightDelta ?? 0))
            let unit = result.unit ?? "kg"

            var lastCreatedSet: WorkoutSetDTO?
            for _ in 0..<count {
                lastCreatedSet = try await workoutRepository.addSet(
                    toExerciseEntryID: created.id,
                    reps: reps,
                    weight: weightValue,
                    unit: unit,
                    side: semantics.side,
                    notes: semantics.notes,
                    isWarmup: semantics.isWarmup,
                    isFailure: semantics.isDropset,
                    durationSeconds: semantics.restSeconds
                )
            }
            lastTouchedSetID = lastCreatedSet?.id
        }

        return ("Added \(created.name)", 1, .addedExercise(exerciseID: created.id))
    }

    private func applyAddSets(
        result: WorkoutCommandResult,
        workoutRepository: WorkoutRepositoryProtocol
    ) async throws -> (summary: String, exercisesAdded: Int, undoAction: UndoAction?) {
        let session = try await resolveActiveSession(workoutRepository: workoutRepository)
        let targetExercise = try await resolveTargetExercise(
            exerciseName: result.exercise,
            sessionID: session.id,
            workoutRepository: workoutRepository
        )

        let existingSets = try await workoutRepository.fetchSets(exerciseEntryID: targetExercise.id)
        let baseSet = existingSets.last
        let semantics = parseSetSemantics(from: result)

        let count = max(1, result.setsToAdd ?? result.sets ?? 1)
        let baseWeight = result.weight ?? baseSet?.weight ?? 0
        let resolvedWeight = max(0, baseWeight + (result.weightDelta ?? 0))
        let reps = Int16(max(0, result.reps ?? 0))
        let unit = result.unit ?? baseSet?.unit ?? "kg"

        var addedSetIDs: [UUID] = []
        var lastSet: WorkoutSetDTO?
        for _ in 0..<count {
            lastSet = try await workoutRepository.addSet(
                toExerciseEntryID: targetExercise.id,
                reps: reps,
                weight: resolvedWeight,
                unit: unit,
                side: semantics.side,
                notes: semantics.notes,
                isWarmup: semantics.isWarmup,
                isFailure: semantics.isDropset,
                durationSeconds: semantics.restSeconds
            )
            if let lastSet {
                addedSetIDs.append(lastSet.id)
            }
        }

        lastTouchedExerciseID = targetExercise.id
        lastTouchedSetID = lastSet?.id

        return (
            "Added \(count) set\(count == 1 ? "" : "s") to \(targetExercise.name)",
            1,
            .addedSets(setIDs: addedSetIDs)
        )
    }

    private func applyRemoveLastSet(
        workoutRepository: WorkoutRepositoryProtocol
    ) async throws -> (summary: String, exercisesAdded: Int, undoAction: UndoAction?) {
        let set = try await resolveTargetSet(workoutRepository: workoutRepository)
        try await workoutRepository.deleteSet(id: set.id)
        lastTouchedSetID = nil
        return ("Deleted last set", 0, .removedSet(set: set))
    }

    private func applyModifyLastSet(
        result: WorkoutCommandResult,
        workoutRepository: WorkoutRepositoryProtocol
    ) async throws -> (summary: String, exercisesAdded: Int, undoAction: UndoAction?) {
        let set = try await resolveTargetSet(workoutRepository: workoutRepository)

        let updatedReps: Int16?
        if let reps = result.reps {
            updatedReps = Int16(max(0, reps))
        } else {
            updatedReps = nil
        }

        let updatedWeight: Double?
        if let weight = result.weight {
            updatedWeight = max(0, weight)
        } else if let delta = result.weightDelta {
            updatedWeight = max(0, set.weight + delta)
        } else {
            updatedWeight = nil
        }

        let semantics = parseSetSemantics(from: result)

        try await workoutRepository.updateSet(
            id: set.id,
            reps: updatedReps,
            weight: updatedWeight,
            unit: result.unit,
            notes: semantics.notes,
            side: semantics.side,
            isWarmup: semantics.isWarmup ? true : nil,
            isFailure: semantics.isDropset ? true : nil,
            durationSeconds: semantics.restSeconds
        )

        return ("Updated last set", 0, .modifiedSet(original: set))
    }

    private func applyRepeatLastExercise(
        result: WorkoutCommandResult,
        workoutRepository: WorkoutRepositoryProtocol
    ) async throws -> (summary: String, exercisesAdded: Int, undoAction: UndoAction?) {
        guard let exerciseIdentityResolver else {
            throw TodayCommandError.validation("Exercise identity resolver is not available.")
        }
        let session = try await resolveActiveSession(workoutRepository: workoutRepository)
        let sourceExercise = try await resolveTargetExercise(
            exerciseName: result.exercise,
            sessionID: session.id,
            workoutRepository: workoutRepository
        )

        let sourceSavedExerciseID: UUID
        if let existing = sourceExercise.savedExerciseID {
            sourceSavedExerciseID = existing
        } else {
            let identity = try await exerciseIdentityResolver.resolve(
                rawInput: sourceExercise.name,
                hintedExerciseName: sourceExercise.name,
                hintedEquipment: sourceExercise.equipment,
                aiPrimaryMusclesText: sourceExercise.primaryMusclesText,
                aiSecondaryMusclesText: sourceExercise.secondaryMusclesText
            )
            sourceSavedExerciseID = identity.savedExerciseID
        }

        let repeatedExercise = try await workoutRepository.addExercise(
            toWorkoutSessionID: session.id,
            name: sourceExercise.name,
            equipment: sourceExercise.equipment,
            savedExerciseID: sourceSavedExerciseID,
            isUnilateral: sourceExercise.isUnilateral
        )

        lastTouchedExerciseID = repeatedExercise.id

        let sourceSets = try await workoutRepository.fetchSets(exerciseEntryID: sourceExercise.id)
        let template = sourceSets.last
        let semantics = parseSetSemantics(from: result)
        if template != nil || result.reps != nil || result.weight != nil || result.weightDelta != nil {
            let reps = Int16(max(0, result.reps ?? 0))
            let startingWeight = result.weight ?? template?.weight ?? 0
            let weight = max(0, startingWeight + (result.weightDelta ?? 0))
            let unit = result.unit ?? template?.unit ?? "kg"
            let set = try await workoutRepository.addSet(
                toExerciseEntryID: repeatedExercise.id,
                reps: reps,
                weight: weight,
                unit: unit,
                side: semantics.side ?? template?.side,
                notes: semantics.notes ?? template?.notes,
                isWarmup: semantics.isWarmup || (template?.isWarmup ?? false),
                isFailure: semantics.isDropset || (template?.isFailure ?? false),
                durationSeconds: semantics.restSeconds ?? template?.durationSeconds
            )
            lastTouchedSetID = set.id
        }

        return ("Repeated \(sourceExercise.name)", 1, .repeatedExercise(exerciseID: repeatedExercise.id))
    }

    private func buildAIContext(workoutRepository: WorkoutRepositoryProtocol) async throws -> WorkoutSessionContext {
        let session = try await resolveActiveSession(workoutRepository: workoutRepository)
        let exercises = try await workoutRepository.fetchExercises(workoutSessionID: session.id)

        let targetExercise: ExerciseEntryDTO?
        if let lastTouchedExerciseID {
            targetExercise = exercises.first(where: { $0.id == lastTouchedExerciseID })
        } else {
            targetExercise = exercises.last
        }

        var lastWeight: Double?
        var lastReps: Int?
        var lastSets: Int?

        if let targetExercise {
            let sets = try await workoutRepository.fetchSets(exerciseEntryID: targetExercise.id)
            if let lastSet = sets.last {
                lastWeight = lastSet.weight
                lastReps = Int(lastSet.reps)
            }
            lastSets = sets.count
        }

        return WorkoutSessionContext(
            lastExercise: targetExercise?.name,
            lastWeight: lastWeight,
            lastReps: lastReps,
            lastSets: lastSets,
            lastEquipment: targetExercise?.equipment
        )
    }

    private func resolveActiveSession(workoutRepository: WorkoutRepositoryProtocol) async throws -> WorkoutSessionDTO {
        let sessions = try await workoutRepository.fetchWorkoutSessions(dayKey: dayKey)

        if let selectedWorkoutSessionID,
           let selected = sessions.first(where: { $0.id == selectedWorkoutSessionID }) {
            return selected
        }

        if let strength = sessions.last(where: { $0.type.lowercased() == "strength" }) {
            selectedWorkoutSessionID = strength.id
            return strength
        }

        if let latest = sessions.last {
            selectedWorkoutSessionID = latest.id
            return latest
        }

        let created = try await workoutRepository.createWorkoutSession(dayKey: dayKey, type: "strength", title: "Workout")
        selectedWorkoutSessionID = created.id
        return created
    }

    private func resolveTargetExercise(
        exerciseName: String?,
        sessionID: UUID,
        workoutRepository: WorkoutRepositoryProtocol
    ) async throws -> ExerciseEntryDTO {
        if let rawName = exerciseName?.trimmingCharacters(in: .whitespacesAndNewlines), !rawName.isEmpty {
            return try await findOrCreateExercise(
                name: rawName,
                equipment: nil,
                sessionID: sessionID,
                workoutRepository: workoutRepository
            )
        }

        if let lastTouchedExerciseID,
           let exercise = try await findExercise(by: lastTouchedExerciseID, workoutRepository: workoutRepository) {
            return exercise
        }

        let exercises = try await workoutRepository.fetchExercises(workoutSessionID: sessionID)
        if let last = exercises.last {
            return last
        }

        throw TodayCommandError.validation("I couldn’t understand that command. Try writing it another way.")
    }

    private func resolveTargetSet(workoutRepository: WorkoutRepositoryProtocol) async throws -> WorkoutSetDTO {
        if let lastTouchedSetID,
           let set = try await findSet(by: lastTouchedSetID, workoutRepository: workoutRepository) {
            return set
        }

        if let lastTouchedExerciseID,
           let exercise = try await findExercise(by: lastTouchedExerciseID, workoutRepository: workoutRepository) {
            let sets = try await workoutRepository.fetchSets(exerciseEntryID: exercise.id)
            if let last = sets.last { return last }
        }

        let session = try await resolveActiveSession(workoutRepository: workoutRepository)
        let exercises = try await workoutRepository.fetchExercises(workoutSessionID: session.id)
        for exercise in exercises.reversed() {
            let sets = try await workoutRepository.fetchSets(exerciseEntryID: exercise.id)
            if let set = sets.last {
                return set
            }
        }

        throw TodayCommandError.validation("I couldn’t understand that command. Try writing it another way.")
    }

    private func findOrCreateExercise(
        name: String,
        equipment: String?,
        sessionID: UUID,
        workoutRepository: WorkoutRepositoryProtocol
    ) async throws -> ExerciseEntryDTO {
        guard let exerciseIdentityResolver else {
            throw TodayCommandError.validation("Exercise identity resolver is not available.")
        }
        let identity = try await exerciseIdentityResolver.resolve(
            rawInput: name,
            hintedExerciseName: name,
            hintedEquipment: equipment
        )

        let exercises = try await workoutRepository.fetchExercises(workoutSessionID: sessionID)
        if let existing = findSessionExercise(
            exercises: exercises,
            matchingSavedExerciseID: identity.savedExerciseID,
            equipmentHint: equipment ?? identity.equipment
        ) {
            return existing
        }

        let created = try await workoutRepository.addExercise(
            toWorkoutSessionID: sessionID,
            name: identity.canonicalName,
            equipment: equipment ?? identity.equipment,
            savedExerciseID: identity.savedExerciseID,
            isUnilateral: false
        )

        try await workoutRepository.updateExercise(
            id: created.id,
            name: nil,
            equipment: equipment ?? identity.equipment,
            notes: nil,
            isUnilateral: nil,
            primaryMusclesText: identity.primaryMusclesText,
            secondaryMusclesText: identity.secondaryMusclesText
        )

        return created
    }

    private func findExercise(by id: UUID, workoutRepository: WorkoutRepositoryProtocol) async throws -> ExerciseEntryDTO? {
        let sessions = try await workoutRepository.fetchWorkoutSessions(dayKey: dayKey)
        for session in sessions {
            let exercises = try await workoutRepository.fetchExercises(workoutSessionID: session.id)
            if let match = exercises.first(where: { $0.id == id }) {
                return match
            }
        }
        return nil
    }

    private func findSet(by id: UUID, workoutRepository: WorkoutRepositoryProtocol) async throws -> WorkoutSetDTO? {
        let sessions = try await workoutRepository.fetchWorkoutSessions(dayKey: dayKey)
        for session in sessions {
            let exercises = try await workoutRepository.fetchExercises(workoutSessionID: session.id)
            for exercise in exercises {
                let sets = try await workoutRepository.fetchSets(exerciseEntryID: exercise.id)
                if let set = sets.first(where: { $0.id == id }) {
                    return set
                }
            }
        }
        return nil
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func findSessionExercise(
        exercises: [ExerciseEntryDTO],
        matchingSavedExerciseID savedExerciseID: UUID,
        equipmentHint: String?
    ) -> ExerciseEntryDTO? {
        let matches = exercises.filter { $0.savedExerciseID == savedExerciseID }
        guard !matches.isEmpty else { return nil }

        guard let equipmentHint, !equipmentHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return matches.last
        }

        let normalizedHint = normalize(equipmentHint)
        if let byEquipment = matches.last(where: { normalize($0.equipment ?? "") == normalizedHint }) {
            return byEquipment
        }

        return matches.last
    }

    private func suggestedWeightForExercise(
        normalizedName: String,
        in sessionID: UUID,
        workoutRepository: WorkoutRepositoryProtocol
    ) async throws -> Double? {
        let exercises = try await workoutRepository.fetchExercises(workoutSessionID: sessionID)
        let matching = exercises.filter { $0.normalizedName == normalizedName }
        guard !matching.isEmpty else { return nil }

        var latestSet: WorkoutSetDTO?
        for exercise in matching {
            let sets = try await workoutRepository.fetchSets(exerciseEntryID: exercise.id)
            guard let last = sets.sorted(by: { $0.orderIndex < $1.orderIndex }).last else { continue }
            if latestSet == nil || last.updatedAt > latestSet!.updatedAt {
                latestSet = last
            }
        }

        return latestSet?.weight
    }

    private func loadSectionsAndRecents() async {
        await loadSections()
        await loadRecents()
        await loadQuickAccessLibrary()
    }

    private func loadSections() async {
        guard let workoutRepository else { return }

        do {
            let fetchedSessions = try await workoutRepository.fetchWorkoutSessions(dayKey: dayKey)
            let sessions = fetchedSessions.sorted {
                if $0.orderIndex == $1.orderIndex {
                    return $0.createdAt < $1.createdAt
                }
                return $0.orderIndex < $1.orderIndex
            }

            if selectedWorkoutSessionID == nil {
                selectedWorkoutSessionID = sessions.last?.id
            } else if let selectedWorkoutSessionID,
                      !sessions.contains(where: { $0.id == selectedWorkoutSessionID }) {
                self.selectedWorkoutSessionID = sessions.last?.id
            }

            var newSections: [SessionSection] = []
            for session in sessions {
                let fetchedExercises = try await workoutRepository.fetchExercises(workoutSessionID: session.id)
                let exercises = fetchedExercises.sorted {
                    if $0.orderIndex == $1.orderIndex {
                        return $0.createdAt < $1.createdAt
                    }
                    return $0.orderIndex < $1.orderIndex
                }
                var exerciseSections: [ExerciseSection] = []

                for exercise in exercises {
                    let fetchedSets = try await workoutRepository.fetchSets(exerciseEntryID: exercise.id)
                    let sets = fetchedSets.sorted {
                        if $0.orderIndex == $1.orderIndex {
                            return $0.createdAt < $1.createdAt
                        }
                        return $0.orderIndex < $1.orderIndex
                    }
                    exerciseSections.append(ExerciseSection(exercise: exercise, sets: sets))
                }

                newSections.append(SessionSection(session: session, exercises: exerciseSections))
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                sessionSections = newSections
                let validWorkoutIDs = Set(newSections.map { $0.session.id })
                expandedWorkoutIDs = expandedWorkoutIDs.intersection(validWorkoutIDs)

                let validExerciseIDs = Set(
                    newSections.flatMap { $0.exercises.map(\.exercise.id) }
                )
                expandedExerciseIDs = expandedExerciseIDs.intersection(validExerciseIDs)
                collapsedExerciseIDs = collapsedExerciseIDs.intersection(validExerciseIDs)

                if expandedWorkoutIDs.isEmpty, let firstSession = newSections.first?.session.id {
                    expandedWorkoutIDs.insert(firstSession)
                }
            }
        } catch {
            commandErrorMessage = error.localizedDescription
            withAnimation(.easeInOut(duration: 0.2)) {
                floatingErrorText = error.localizedDescription
            }
        }
    }

    private func loadRecents() async {
        guard let recentItemsRepository else { return }

        do {
            let items = try await recentItemsRepository.fetchRecentSnippets(limit: 30)
            var seen = Set<String>()
            var deduped: [RecentWorkoutSnippetDTO] = []

            for item in items {
                let key = item.normalizedTitle
                if seen.contains(key) { continue }
                seen.insert(key)
                deduped.append(item)
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                recentSnippets = deduped
            }
        } catch {
            // Keep UI resilient if recents fetch fails.
        }
    }

    private func loadQuickAccessLibrary() async {
        guard let exerciseRepository else { return }

        do {
            let templates = try await exerciseRepository.fetchFavoriteSnippets()
                .filter { $0.snippetType.contains("template") }
            let saved = try await exerciseRepository.fetchSavedExercises()

            withAnimation(.easeInOut(duration: 0.2)) {
                templateSnippets = templates
                savedExercises = saved
            }
        } catch {
            // Keep UI resilient if library fetch fails.
        }
    }

    func applyTemplateSnippet(_ template: FavoriteWorkoutSnippetDTO) {
        guard let workoutRepository else { return }

        Task {
            do {
                let targetSessionID = try await resolveActiveSession(workoutRepository: workoutRepository).id
                let payload = try decodeTemplatePayload(from: template.payloadJSON, fallbackName: template.title)

                let added = try await workoutRepository.addExercise(
                    toWorkoutSessionID: targetSessionID,
                    name: payload.name,
                    equipment: payload.equipment,
                    savedExerciseID: template.savedExerciseID,
                    isUnilateral: payload.isUnilateral
                )

                try await workoutRepository.updateExercise(
                    id: added.id,
                    name: nil,
                    equipment: payload.equipment,
                    notes: nil,
                    isUnilateral: payload.isUnilateral,
                    primaryMusclesText: payload.primaryMusclesText,
                    secondaryMusclesText: payload.secondaryMusclesText
                )

                if !payload.sets.isEmpty {
                    for set in payload.sets {
                        _ = try await workoutRepository.addSet(
                            toExerciseEntryID: added.id,
                            reps: set.reps,
                            weight: set.weight,
                            unit: set.unit,
                            side: set.side,
                            notes: set.notes,
                            isWarmup: set.isWarmup,
                            isFailure: set.isFailure,
                            durationSeconds: set.durationSeconds
                        )
                    }
                }

                if let exerciseRepository {
                    try? await exerciseRepository.markUsed(id: template.savedExerciseID)
                }

                showRecentsSheet = false
                await loadSectionsAndRecents()
            } catch {
                floatingErrorText = error.localizedDescription
            }
        }
    }

    func addSavedExerciseQuick(_ item: SavedExerciseDTO) {
        Task {
            do {
                guard let workoutRepository else { return }
                let session = try await resolveActiveSession(workoutRepository: workoutRepository)
                let added = try await workoutRepository.addExercise(
                    toWorkoutSessionID: session.id,
                    name: item.name,
                    equipment: item.equipment,
                    savedExerciseID: item.id,
                    isUnilateral: false
                )

                try await workoutRepository.updateExercise(
                    id: added.id,
                    name: nil,
                    equipment: item.equipment,
                    notes: nil,
                    isUnilateral: false,
                    primaryMusclesText: item.primaryMusclesText,
                    secondaryMusclesText: item.secondaryMusclesText
                )

                if let exerciseRepository {
                    try? await exerciseRepository.markUsed(id: item.id)
                }

                showRecentsSheet = false
                await loadSectionsAndRecents()
            } catch {
                floatingErrorText = error.localizedDescription
            }
        }
    }

    private func decodeTemplatePayload(from rawJSON: String, fallbackName: String) throws -> ExerciseTemplatePayload {
        guard let data = rawJSON.data(using: .utf8) else {
            throw NSError(domain: "Template", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid template data"])
        }
        do {
            return try JSONDecoder().decode(ExerciseTemplatePayload.self, from: data)
        } catch {
            let cleanedName = fallbackName
                .replacingOccurrences(of: " empty template", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " template", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ExerciseTemplatePayload(
                name: cleanedName.isEmpty ? "Template Exercise" : cleanedName,
                equipment: nil,
                isUnilateral: false,
                primaryMusclesText: nil,
                secondaryMusclesText: nil,
                sets: []
            )
        }
    }

    private func learnCommandResolutionIfNeeded(rawText: String, result: WorkoutCommandResult) async {
        guard let commandResolutionCache, let exerciseIdentityResolver else { return }
        guard result.action == .addExercise || result.action == .addSets || result.action == .repeatLastExercise else {
            return
        }

        guard let exerciseName = result.exercise?.trimmingCharacters(in: .whitespacesAndNewlines),
              !exerciseName.isEmpty else {
            return
        }

        if let resolution = try? await exerciseIdentityResolver.resolve(
            rawInput: rawText,
            hintedExerciseName: exerciseName,
            hintedEquipment: result.equipment
        ) {
            await commandResolutionCache.learn(
                rawInput: rawText,
                resolvedExerciseName: resolution.canonicalName,
                resolvedIntent: result.action.rawValue
            )
        }
    }

    private func saveRecentSnippetIfNeeded(_ summary: String) async {
        guard let recentItemsRepository, !summary.isEmpty else { return }
        try? await recentItemsRepository.saveRecentSnippet(
            title: summary,
            payloadJSON: "{}",
            snippetType: "command",
            sourceDayKey: dayKey
        )
    }

    private func saveCommandHistory(rawText: String, commandType: String?, success: Bool) async {
        guard let commandHistoryRepository else { return }
        let item = CommandHistoryItemDTO(
            id: UUID(),
            rawText: rawText,
            parsedCommandType: commandType,
            dayKey: dayKey,
            workoutSessionID: selectedWorkoutSessionID,
            createdAt: Date(),
            success: success
        )
        try? await commandHistoryRepository.save(item: item)
    }

    private struct SetSemantics {
        var isWarmup: Bool
        var isDropset: Bool
        var side: String?
        var restSeconds: Int32?
        var notes: String?
    }

    private func parseSetSemantics(from result: WorkoutCommandResult) -> SetSemantics {
        let raw = result.modifiers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        let isWarmup = raw.contains(where: { $0 == "warmup" || $0 == "calentamiento" })
        let isDropset = raw.contains(where: { $0 == "dropset" || $0 == "drop_set" || $0 == "drop set" })

        let side: String?
        if raw.contains(where: { $0 == "left" || $0 == "l" || $0 == "izquierda" }) {
            side = "left"
        } else if raw.contains(where: { $0 == "right" || $0 == "r" || $0 == "derecha" }) {
            side = "right"
        } else {
            side = nil
        }

        let restFromModifier = raw.compactMap { parseRestSeconds(modifier: $0) }.first
        let restSeconds = result.restSeconds.flatMap { Int32(max(0, $0)) } ?? restFromModifier

        var notes = result.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        if notes?.isEmpty == true {
            notes = nil
        }

        if isDropset {
            let marker = "[dropset]"
            if let existingNotes = notes, !existingNotes.lowercased().contains(marker) {
                notes = "\(marker) \(existingNotes)"
            } else if notes == nil {
                notes = marker
            }
        }

        return SetSemantics(
            isWarmup: isWarmup,
            isDropset: isDropset,
            side: side,
            restSeconds: restSeconds,
            notes: notes
        )
    }

    private func parseRestSeconds(modifier: String) -> Int32? {
        let compact = modifier.replacingOccurrences(of: " ", with: "")
        guard compact.hasPrefix("rest_") || compact.hasPrefix("descanso_") else { return nil }

        let digits = compact.filter(\.isNumber)
        guard let value = Int(digits) else { return nil }
        return Int32(max(0, value))
    }
}

private enum TodayCommandError: LocalizedError {
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .validation(let message):
            return message
        }
    }
}
