import Foundation

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

    struct PendingCommandClarification: Identifiable {
        let id: UUID
        let request: CommandConfirmationRequest
        let originalInput: String
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
    var pendingCommandClarification: PendingCommandClarification? = nil
    var clarificationCustomText: String = ""

    let processingMessages: [String] = [
        "Analizando comando...",
        "Entendiendo el ejercicio...",
        "Buscando en el contexto...",
        "Interpretando series y peso...",
        "Procesando comando...",
        "Guardando en el entrenamiento...",
        "Casi listo...",
    ]

    private var router: AppRouter
    private var workoutRepository: WorkoutRepositoryProtocol?
    private var recentItemsRepository: RecentItemsRepositoryProtocol?
    private var commandHistoryRepository: CommandHistoryRepositoryProtocol?
    private var commandInterpreter: WorkoutCommandInterpreter?

    private var processingMessageTask: Task<Void, Never>?
    private var processingCommandTask: Task<Void, Never>?
    private var pendingCancelInputText: String = ""

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
        recentItemsRepository: RecentItemsRepositoryProtocol,
        commandHistoryRepository: CommandHistoryRepositoryProtocol,
        commandInterpreter: WorkoutCommandInterpreter
    ) {
        self.workoutRepository = workoutRepository
        self.recentItemsRepository = recentItemsRepository
        self.commandHistoryRepository = commandHistoryRepository
        self.commandInterpreter = commandInterpreter
    }

    // MARK: - Lifecycle

    func onAppear() {
        load()
        Task { await commandInterpreter?.resolutionCache.load() }
    }

    func load() {
        Task {
            await loadSections()
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

    // MARK: - Command input

    func submitCommand() {
        let trimmed = commandInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isProcessingCommand else {
            // If already processing, tapping submit acts as cancel
            if isProcessingCommand { cancelCurrentCommand() }
            return
        }
        pendingCancelInputText = trimmed
        processingCommandTask = Task {
            await submitCommandInternal(rawText: trimmed)
        }
    }

    func cancelCurrentCommand() {
        processingCommandTask?.cancel()
        processingCommandTask = nil
        stopProcessingMessages()
        isProcessingCommand = false
        commandErrorMessage = nil
        // Restore the text the user typed so they can edit and retry
        commandInputText = pendingCancelInputText
    }

    func chooseClarificationOption(_ choice: CommandConfirmationChoice) {
        guard !isProcessingCommand else { return }
        Task {
            await executeClarificationChoice(choice)
        }
    }

    func submitClarificationCustomText() {
        let custom = clarificationCustomText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !custom.isEmpty else { return }
        pendingCommandClarification = nil
        clarificationCustomText = ""
        commandInputText = custom
        submitCommand()
    }

    func dismissClarificationSheet() {
        pendingCommandClarification = nil
        clarificationCustomText = ""
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
                await loadSections()
            } catch {
                commandErrorMessage = error.localizedDescription
            }
        }
    }

    func tapExercise(id: UUID) {
        lastTouchedExerciseID = id
    }

    func tapSet(id: UUID) {
        lastTouchedSetID = id
    }

    func duplicateSet(id: UUID) {
        Task {
            guard let workoutRepository else { return }
            do {
                let duplicated = try await workoutRepository.duplicateSet(id: id, modifier: nil)
                lastTouchedSetID = duplicated.id
                lastTouchedExerciseID = duplicated.exerciseEntryID
                await loadSections()
            } catch {
                commandErrorMessage = error.localizedDescription
            }
        }
    }

    func deleteSet(id: UUID) {
        Task {
            guard let workoutRepository else { return }
            do {
                try await workoutRepository.deleteSet(id: id)
                lastTouchedSetID = nil
                await loadSections()
            } catch {
                commandErrorMessage = error.localizedDescription
            }
        }
    }

    func addSetToExercise(exerciseID: UUID) {
        Task {
            guard let workoutRepository else { return }
            do {
                let set = try await workoutRepository.addSet(toExerciseEntryID: exerciseID, reps: 8, weight: 0, unit: "kg")
                lastTouchedSetID = set.id
                lastTouchedExerciseID = exerciseID
                await loadSections()
            } catch {
                commandErrorMessage = error.localizedDescription
            }
        }
    }

    func addExerciseFromFavorite(snippetID: UUID) {
        _ = snippetID
        // TODO: exerciseRepository.addFavoriteExerciseToWorkout(...)
    }

    func addRecentSnippet(snippetID: UUID) {
        _ = snippetID
        // TODO: recentItemsRepository-based add
    }

    // MARK: - Internal command execution

    private func submitCommandInternal(rawText: String) async {
        guard let commandInterpreter, let workoutRepository else {
            commandErrorMessage = "Today dependencies are not available yet."
            return
        }

        isProcessingCommand = true
        startProcessingMessages()
        commandErrorMessage = nil
        recentCommandSummary = nil

        var executionSucceeded = false
        var summaryForHistory = ""

        defer {
            stopProcessingMessages()
            isProcessingCommand = false
        }

        let currentExercises = sessionSections
            .first(where: { $0.session.id == selectedWorkoutSessionID })
            .map { $0.exercises.map(\.exercise) } ?? []

        let context = WorkoutCommandContext(
            dayKey: dayKey,
            selectedWorkoutSessionID: selectedWorkoutSessionID,
            exercisesInCurrentSession: currentExercises,
            lastTouchedExerciseID: lastTouchedExerciseID,
            lastTouchedSetID: lastTouchedSetID,
            selectedExerciseID: lastTouchedExerciseID,
            preferredWeightUnit: "kg"
        )

        let plan = await commandInterpreter.interpret(input: rawText, context: context)

        if case .requiresConfirmation(let request) = plan.validationResult {
            presentCommandClarification(request, originalInput: rawText)
            await saveCommandHistory(rawText: rawText, command: plan.command, success: false)
            return
        }
        if case .askForConfirmation(let request) = plan.command {
            presentCommandClarification(request, originalInput: rawText)
            await saveCommandHistory(rawText: rawText, command: plan.command, success: false)
            return
        }

        do {
            summaryForHistory = try await execute(plan: plan, workoutRepository: workoutRepository)
            executionSucceeded = true
            commandInputText = ""
            recentCommandSummary = summaryForHistory
            await saveRecentSnippetIfNeeded(summaryForHistory)

            await loadSections()
        } catch {
            commandErrorMessage = error.localizedDescription
        }

        await saveCommandHistory(rawText: rawText, command: plan.command, success: executionSucceeded)
    }

    private func execute(plan: WorkoutCommandExecutionPlan, workoutRepository: WorkoutRepositoryProtocol) async throws -> String {
        switch plan.validationResult {
        case .valid:
            break
        case .invalid(let reason):
            throw TodayCommandError.validation(reason)
        case .requiresConfirmation(let request):
            throw TodayCommandError.validation(request.prompt)
        case .requiresProFeature(let feature):
            router.presentProGate(feature: feature)
            throw TodayCommandError.validation("This command requires Pro")
        }

        switch plan.command {
        case .addExercise(let command):
            let session = try await resolveActiveSession(workoutRepository: workoutRepository)
            let parsed = splitExerciseNameAndEquipment(command.name)
            let exercise = try await workoutRepository.addExercise(
                toWorkoutSessionID: session.id,
                name: parsed.name,
                equipment: parsed.equipment,
                savedExerciseID: nil
            )
            lastTouchedExerciseID = exercise.id
            return "Added \(exercise.name)"

        case .addSet(let command):
            return try await addSet(command: command, workoutRepository: workoutRepository)

        case .addMultipleSets(let command):
            return try await addMultipleSets(command: command, workoutRepository: workoutRepository)

        case .duplicateSet(let command):
            let baseSet = try await resolveSetTarget(command.target, workoutRepository: workoutRepository)
            let duplicated = try await workoutRepository.duplicateSet(id: baseSet.id, modifier: command.modifier)
            lastTouchedSetID = duplicated.id
            lastTouchedExerciseID = duplicated.exerciseEntryID
            return command.metadata.userVisibleSummary.isEmpty ? "Duplicated set" : command.metadata.userVisibleSummary

        case .deleteSet(let command):
            let set = try await resolveSetTarget(command.target, workoutRepository: workoutRepository)
            try await workoutRepository.deleteSet(id: set.id)
            lastTouchedSetID = nil
            return "Deleted last set"

        case .askForConfirmation(let request):
            throw TodayCommandError.validation(request.prompt)

        case .unknown(let rawText):
            throw TodayCommandError.validation("Could not understand command: \(rawText)")

        case .updateSet, .saveExerciseAsFavorite, .saveSetAsFavorite, .addFavoriteToWorkout,
                .addRecentToWorkout, .startWorkoutSession, .switchWorkoutSession:
            throw TodayCommandError.validation("This command is not supported yet in Today")
        }
    }

    private func addSet(command: AddSetCommand, workoutRepository: WorkoutRepositoryProtocol) async throws -> String {
        let session = try await resolveActiveSession(workoutRepository: workoutRepository)
        let targetExercise = try await resolveExerciseTarget(
            command.target,
            sessionID: session.id,
            fallbackEquipment: command.set.notes,
            workoutRepository: workoutRepository
        )

        let existingSets = try await workoutRepository.fetchSets(exerciseEntryID: targetExercise.id)
        let baseSet = existingSets.last
        let resolvedReps = command.set.reps ?? Int(baseSet?.reps ?? 8)
        let resolvedWeight = command.set.weight ?? baseSet?.weight ?? 0
        let resolvedUnit = command.set.unit ?? baseSet?.unit ?? "kg"

        let reps = Int16(max(0, resolvedReps))
        let weight = max(0, resolvedWeight)
        let unit = resolvedUnit

        let set = try await workoutRepository.addSet(
            toExerciseEntryID: targetExercise.id,
            reps: reps,
            weight: weight,
            unit: unit
        )

        lastTouchedExerciseID = targetExercise.id
        lastTouchedSetID = set.id

        let weightText = unit == "bodyweight" ? "bodyweight" : "\(formatWeight(weight)) \(unit)"
        return "Added \(targetExercise.name) · \(reps) × \(weightText)"
    }

    private func addMultipleSets(command: AddMultipleSetsCommand, workoutRepository: WorkoutRepositoryProtocol) async throws -> String {
        let session = try await resolveActiveSession(workoutRepository: workoutRepository)
        let targetExercise = try await resolveExerciseTarget(
            command.target,
            sessionID: session.id,
            fallbackEquipment: command.sets.first?.notes,
            workoutRepository: workoutRepository
        )

        let existingSets = try await workoutRepository.fetchSets(exerciseEntryID: targetExercise.id)
        let baseSet = existingSets.last

        var lastSet: WorkoutSetDTO?
        for parsedSet in command.sets {
            let resolvedReps = parsedSet.reps ?? Int(baseSet?.reps ?? 8)
            let resolvedUnit = parsedSet.unit ?? baseSet?.unit ?? "kg"
            let resolvedWeight = parsedSet.weight ?? baseSet?.weight ?? 0

            let reps = Int16(max(0, resolvedReps))
            let weight = max(0, resolvedWeight)
            let unit = resolvedUnit
            lastSet = try await workoutRepository.addSet(
                toExerciseEntryID: targetExercise.id,
                reps: reps,
                weight: weight,
                unit: unit
            )
        }

        lastTouchedExerciseID = targetExercise.id
        lastTouchedSetID = lastSet?.id
        return "Added \(command.sets.count) sets to \(targetExercise.name)"
    }

    private func resolveActiveSession(workoutRepository: WorkoutRepositoryProtocol) async throws -> WorkoutSessionDTO {
        let sessions = try await workoutRepository.fetchWorkoutSessions(dayKey: dayKey)

        if let selectedWorkoutSessionID,
           let selected = sessions.first(where: { $0.id == selectedWorkoutSessionID }) {
            return selected
        }

        if let latest = sessions.last {
            selectedWorkoutSessionID = latest.id
            return latest
        }

        let created = try await workoutRepository.createWorkoutSession(dayKey: dayKey, type: "strength", title: "Workout")
        selectedWorkoutSessionID = created.id
        return created
    }

    private func resolveExerciseTarget(
        _ target: WorkoutCommandTarget,
        sessionID: UUID,
        fallbackEquipment: String?,
        workoutRepository: WorkoutRepositoryProtocol
    ) async throws -> ExerciseEntryDTO {
        switch target {
        case .exercise(let id):
            if let match = try await findExercise(by: id, workoutRepository: workoutRepository) {
                return match
            }

        case .exerciseName(let name):
            return try await findOrCreateExercise(
                name: name,
                equipment: fallbackEquipment,
                sessionID: sessionID,
                workoutRepository: workoutRepository
            )

        case .lastTouchedExercise, .selectedExercise:
            if let lastTouchedExerciseID,
               let match = try await findExercise(by: lastTouchedExerciseID, workoutRepository: workoutRepository) {
                return match
            }

        case .previousExercise:
            if let lastTouchedExerciseID,
               let match = try await findExercise(by: lastTouchedExerciseID, workoutRepository: workoutRepository) {
                return match
            }
            let exercises = try await workoutRepository.fetchExercises(workoutSessionID: sessionID)
            if let last = exercises.last { return last }

        case .currentWorkout:
            let exercises = try await workoutRepository.fetchExercises(workoutSessionID: sessionID)
            if let last = exercises.last { return last }

        default:
            break
        }

        throw TodayCommandError.validation("Could not resolve exercise target")
    }

    private func resolveSetTarget(_ target: WorkoutCommandTarget, workoutRepository: WorkoutRepositoryProtocol) async throws -> WorkoutSetDTO {
        switch target {
        case .lastTouchedSet:
            if let lastTouchedSetID,
               let set = try await findSet(by: lastTouchedSetID, workoutRepository: workoutRepository) {
                return set
            }

        case .selectedExercise, .previousExercise, .lastTouchedExercise:
            let session = try await resolveActiveSession(workoutRepository: workoutRepository)
            let exercise = try await resolveExerciseTarget(
                target,
                sessionID: session.id,
                fallbackEquipment: nil,
                workoutRepository: workoutRepository
            )
            let sets = try await workoutRepository.fetchSets(exerciseEntryID: exercise.id)
            if let last = sets.last { return last }

        case .exercise(let exerciseID):
            let sets = try await workoutRepository.fetchSets(exerciseEntryID: exerciseID)
            if let last = sets.last { return last }

        case .exerciseName(let name):
            let session = try await resolveActiveSession(workoutRepository: workoutRepository)
            let exercise = try await findOrCreateExercise(
                name: name,
                equipment: nil,
                sessionID: session.id,
                workoutRepository: workoutRepository
            )
            let sets = try await workoutRepository.fetchSets(exerciseEntryID: exercise.id)
            if let last = sets.last { return last }

        default:
            break
        }

        // final fallback: latest set in selected session
        let session = try await resolveActiveSession(workoutRepository: workoutRepository)
        let exercises = try await workoutRepository.fetchExercises(workoutSessionID: session.id)
        for exercise in exercises.reversed() {
            let sets = try await workoutRepository.fetchSets(exerciseEntryID: exercise.id)
            if let set = sets.last { return set }
        }

        throw TodayCommandError.validation("No set available to update")
    }

    private func findOrCreateExercise(
        name: String,
        equipment: String?,
        sessionID: UUID,
        workoutRepository: WorkoutRepositoryProtocol
    ) async throws -> ExerciseEntryDTO {
        let normalized = normalize(name)
        let exercises = try await workoutRepository.fetchExercises(workoutSessionID: sessionID)
        if let existing = exercises.first(where: { $0.normalizedName == normalized }) {
            return existing
        }

        return try await workoutRepository.addExercise(
            toWorkoutSessionID: sessionID,
            name: name,
            equipment: equipment,
            savedExerciseID: nil
        )
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

    private func loadSections() async {
        guard let workoutRepository else { return }

        do {
            let sessions = try await workoutRepository.fetchWorkoutSessions(dayKey: dayKey)

            if selectedWorkoutSessionID == nil {
                selectedWorkoutSessionID = sessions.last?.id
            } else if let selectedWorkoutSessionID,
                      !sessions.contains(where: { $0.id == selectedWorkoutSessionID }) {
                self.selectedWorkoutSessionID = sessions.last?.id
            }

            var newSections: [SessionSection] = []
            for session in sessions {
                let exercises = try await workoutRepository.fetchExercises(workoutSessionID: session.id)
                var exerciseSections: [ExerciseSection] = []

                for exercise in exercises {
                    let sets = try await workoutRepository.fetchSets(exerciseEntryID: exercise.id)
                    exerciseSections.append(ExerciseSection(exercise: exercise, sets: sets))
                }

                newSections.append(SessionSection(session: session, exercises: exerciseSections))
            }

            sessionSections = newSections
        } catch {
            commandErrorMessage = error.localizedDescription
        }
    }

    private func commandTypeName(for command: ParsedWorkoutCommand) -> String {
        switch command {
        case .addExercise: return "addExercise"
        case .addSet: return "addSet"
        case .addMultipleSets: return "addMultipleSets"
        case .duplicateSet: return "duplicateSet"
        case .updateSet: return "updateSet"
        case .deleteSet: return "deleteSet"
        case .saveExerciseAsFavorite: return "saveExerciseAsFavorite"
        case .saveSetAsFavorite: return "saveSetAsFavorite"
        case .addFavoriteToWorkout: return "addFavoriteToWorkout"
        case .addRecentToWorkout: return "addRecentToWorkout"
        case .startWorkoutSession: return "startWorkoutSession"
        case .switchWorkoutSession: return "switchWorkoutSession"
        case .askForConfirmation: return "askForConfirmation"
        case .unknown: return "unknown"
        }
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func formatWeight(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private func splitExerciseNameAndEquipment(_ raw: String) -> (name: String, equipment: String?) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let separators = [" en ", " with ", " in "]

        for separator in separators {
            if let range = normalized.range(of: separator, options: .caseInsensitive) {
                let name = String(normalized[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let equipment = String(normalized[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, !equipment.isEmpty {
                    return (name, equipment)
                }
            }
        }

        return (normalized, nil)
    }

    private func presentCommandClarification(_ request: CommandConfirmationRequest, originalInput: String) {
        pendingCommandClarification = PendingCommandClarification(
            id: UUID(),
            request: request,
            originalInput: originalInput
        )
        clarificationCustomText = originalInput
        commandErrorMessage = nil
    }

    private func executeClarificationChoice(_ choice: CommandConfirmationChoice) async {
        guard let workoutRepository else {
            commandErrorMessage = "Today dependencies are not available yet."
            return
        }
        let clarificationRawText = pendingCommandClarification?.originalInput ?? choice.label
        pendingCommandClarification = nil

        isProcessingCommand = true
        startProcessingMessages()
        commandErrorMessage = nil
        recentCommandSummary = nil

        var executionSucceeded = false
        defer {
            stopProcessingMessages()
            isProcessingCommand = false
        }

        let plan = WorkoutCommandExecutionPlan(
            command: choice.command,
            validationResult: .valid,
            metadata: metadata(for: choice.command)
        )

        do {
            let summary = try await execute(plan: plan, workoutRepository: workoutRepository)
            recentCommandSummary = summary
            pendingCommandClarification = nil
            clarificationCustomText = ""
            commandInputText = ""
            executionSucceeded = true

            // Learn the resolution so next time this input is recognized directly
            await learnResolution(from: choice.command, originalInput: clarificationRawText)

            await saveRecentSnippetIfNeeded(summary)
            await loadSections()
        } catch {
            commandErrorMessage = error.localizedDescription
        }

        await saveCommandHistory(rawText: clarificationRawText, command: choice.command, success: executionSucceeded)
    }

    private func learnResolution(from command: ParsedWorkoutCommand, originalInput: String) async {
        guard let cache = commandInterpreter?.resolutionCache else { return }
        switch command {
        case .addSet(let c):
            if case .exerciseName(let name) = c.target {
                await cache.learn(rawInput: originalInput, resolvedExerciseName: name, resolvedIntent: "add_set")
            }
        case .addMultipleSets(let c):
            if case .exerciseName(let name) = c.target {
                await cache.learn(rawInput: originalInput, resolvedExerciseName: name, resolvedIntent: "add_multiple_sets")
            }
        case .addExercise(let c):
            await cache.learn(rawInput: originalInput, resolvedExerciseName: c.name, resolvedIntent: "add_exercise")
        default:
            break
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

    private func saveCommandHistory(rawText: String, command: ParsedWorkoutCommand, success: Bool) async {
        guard let commandHistoryRepository else { return }
        let item = CommandHistoryItemDTO(
            id: UUID(),
            rawText: rawText,
            parsedCommandType: commandTypeName(for: command),
            dayKey: dayKey,
            workoutSessionID: selectedWorkoutSessionID,
            createdAt: Date(),
            success: success
        )
        try? await commandHistoryRepository.save(item: item)
    }

    private func metadata(for command: ParsedWorkoutCommand) -> ParsedCommandMetadata {
        switch command {
        case .addExercise(let command): return command.metadata
        case .addSet(let command): return command.metadata
        case .addMultipleSets(let command): return command.metadata
        case .duplicateSet(let command): return command.metadata
        case .updateSet(let command): return command.metadata
        case .deleteSet(let command): return command.metadata
        case .saveExerciseAsFavorite(let command): return command.metadata
        case .saveSetAsFavorite(let command): return command.metadata
        case .addFavoriteToWorkout(let command): return command.metadata
        case .addRecentToWorkout(let command): return command.metadata
        case .startWorkoutSession(let command): return command.metadata
        case .switchWorkoutSession(let command): return command.metadata
        case .askForConfirmation:
            return ParsedCommandMetadata(
                confidence: 0,
                source: .fallback,
                needsConfirmation: true,
                userVisibleSummary: "Command requires confirmation"
            )
        case .unknown:
            return ParsedCommandMetadata(
                confidence: 0,
                source: .fallback,
                needsConfirmation: true,
                userVisibleSummary: "Unknown command"
            )
        }
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
