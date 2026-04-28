import Foundation

final class WorkoutCommandInterpreter {

    private let localParser: LocalWorkoutCommandParser
    private let foundationModelsParser: FoundationModelsWorkoutCommandParser
    private let entitlementService: EntitlementServiceProtocol
    let resolutionCache: CommandResolutionCache
    private static let afmPreferredConfidence: Double = 0.9

    init(
        localParser: LocalWorkoutCommandParser = LocalWorkoutCommandParser(),
        entitlementService: EntitlementServiceProtocol,
        resolutionCache: CommandResolutionCache
    ) {
        self.localParser = localParser
        self.foundationModelsParser = FoundationModelsWorkoutCommandParser(entitlementService: entitlementService)
        self.entitlementService = entitlementService
        self.resolutionCache = resolutionCache
    }

    func interpret(input: String, context: WorkoutCommandContext) async -> WorkoutCommandExecutionPlan {
        _ = entitlementService

        // 0) Check learned resolutions — if this input was clarified before, resolve instantly.
        if let learned = await resolutionCache.resolve(input: input) {
            let meta = ParsedCommandMetadata(
                confidence: 0.99,
                source: .localParser,
                needsConfirmation: false,
                userVisibleSummary: "Add set to \(learned.resolvedExerciseName)"
            )
            let target = WorkoutCommandTarget.exerciseName(learned.resolvedExerciseName)
            let command: ParsedWorkoutCommand
            switch learned.resolvedIntent {
            case "add_exercise":
                command = .addExercise(AddExerciseCommand(name: learned.resolvedExerciseName, target: .currentWorkout, initialSet: nil, metadata: meta))
            case "add_multiple_sets":
                let set = ParsedSet(reps: nil, weight: nil, unit: context.preferredWeightUnit)
                command = .addMultipleSets(AddMultipleSetsCommand(target: target, sets: [set, set], metadata: meta))
            default:
                let set = ParsedSet(reps: nil, weight: nil, unit: context.preferredWeightUnit)
                command = .addSet(AddSetCommand(target: target, set: set, metadata: meta))
            }
            await resolutionCache.incrementUseCount(id: learned.id)
            return WorkoutCommandExecutionPlan(command: command, validationResult: .valid, metadata: meta)
        }

        // 1) Foundation Models first, but we also parse locally and arbitrate.
        let fmPlan = await foundationModelsParser.parse(input: input, context: context)
        let localPlan = await localParser.parse(input: input, context: context)

        let fmIsValid = isValid(fmPlan)
        let localIsValid = isValid(localPlan)

        // 2) Both valid: prefer the most plausible plan for this concrete text.
        if fmIsValid && localIsValid {
            return chooseBetweenValidPlans(input: input, fmPlan: fmPlan, localPlan: localPlan)
        }

        // 3) Single valid.
        if fmIsValid { return fmPlan }
        if localIsValid { return localPlan }

        // 4) Keep FM result when it is explicit about gating/confirmation.
        switch fmPlan.validationResult {
        case .requiresConfirmation, .requiresProFeature:
            return fmPlan
        case .valid, .invalid:
            break
        }

        // 5) Unknown fallback.
        if case .unknown = localPlan.command {
            if let bestEffort = buildBestEffortExercisePlan(for: input) {
                return bestEffort
            }
            if case .invalid(let fmReason) = fmPlan.validationResult {
                return buildConfirmationPlan(for: input, debugReason: fmReason)
            }
            return buildConfirmationPlan(for: input)
        }

        if case .invalid = localPlan.validationResult {
            return buildConfirmationPlan(for: input)
        }

        return localPlan
    }

    private func isValid(_ plan: WorkoutCommandExecutionPlan) -> Bool {
        if case .valid = plan.validationResult { return true }
        return false
    }

    private func chooseBetweenValidPlans(
        input: String,
        fmPlan: WorkoutCommandExecutionPlan,
        localPlan: WorkoutCommandExecutionPlan
    ) -> WorkoutCommandExecutionPlan {
        // Reliability first: local parser should be the default winner when both plans are valid.
        if localPlan.metadata.confidence >= 0.8 {
            return localPlan
        }

        if shouldPreferLocal(for: input, fmPlan: fmPlan, localPlan: localPlan) {
            return localPlan
        }

        // AFM only wins when it is clearly stronger.
        if fmPlan.metadata.confidence >= Self.afmPreferredConfidence
            && fmPlan.metadata.confidence > localPlan.metadata.confidence + 0.1 {
            return fmPlan
        }

        return localPlan
    }

    private func shouldPreferLocal(
        for input: String,
        fmPlan: WorkoutCommandExecutionPlan,
        localPlan: WorkoutCommandExecutionPlan
    ) -> Bool {
        let normalized = input
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let followUpTokens = [
            "serie", "series", "set", "sets",
            "otra igual", "same", "duplicate",
            "ultima serie", "last set",
            "ejercicio anterior", "previous exercise"
        ]
        let isFollowUpText = followUpTokens.contains { normalized.contains($0) }

        if isFollowUpText {
            if isSetOrUpdateCommand(localPlan.command), !isSetOrUpdateCommand(fmPlan.command) {
                return true
            }
        }

        if case .addExercise(let fmAddExercise) = fmPlan.command {
            let suspiciousName = fmAddExercise.name
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
            let suspiciousExerciseGuess =
                suspiciousName.contains("serie")
                || suspiciousName.contains("set")
                || suspiciousName.contains("last")
                || suspiciousName.contains("ultima")
                || suspiciousName.range(of: #"\d+\s*(x|reps?|kg|lb)"#, options: .regularExpression) != nil
            if suspiciousExerciseGuess && isSetOrUpdateCommand(localPlan.command) {
                return true
            }
        }

        return false
    }

    private func isSetOrUpdateCommand(_ command: ParsedWorkoutCommand) -> Bool {
        switch command {
        case .addSet, .addMultipleSets, .duplicateSet, .deleteSet, .updateSet:
            return true
        default:
            return false
        }
    }

    private func buildBestEffortExercisePlan(for input: String) -> WorkoutCommandExecutionPlan? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = normalize(trimmed)

        let blocked = [
            "borra", "elimina", "delete", "remove", "clear",
            "settings", "calendar", "ajustes", "calendario",
            "serie", "series", "set", "sets", "reps", "kg", "lb",
            "duplica", "duplicate", "igual", "last", "ultima", "última"
        ]
        guard !blocked.contains(where: normalized.contains) else { return nil }

        let cleaned = trimmed
            .replacingOccurrences(of: #"^\s*(quiero|hacer|hazme|anade|añade|add)\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let words = cleaned.split(separator: " ")
        guard cleaned.count >= 3, words.count <= 6 else { return nil }
        guard cleaned.range(of: #"\d"#, options: .regularExpression) == nil else { return nil }

        let metadata = ParsedCommandMetadata(
            confidence: 0.55,
            source: .fallback,
            needsConfirmation: false,
            userVisibleSummary: "Best effort: added exercise \(cleaned)"
        )
        let command = ParsedWorkoutCommand.addExercise(
            AddExerciseCommand(name: cleaned, target: .currentWorkout, initialSet: nil, metadata: metadata)
        )
        return WorkoutCommandExecutionPlan(command: command, validationResult: .valid, metadata: metadata)
    }

    private func buildConfirmationPlan(for input: String, debugReason: String? = nil) -> WorkoutCommandExecutionPlan {
        let choices = buildConfirmationChoices(for: input)
        let prompt = "No entendí del todo \"\(input)\". Elige qué querías hacer o escribe una opción personalizada."
        let confirmation = CommandConfirmationRequest(
            prompt: prompt,
            choices: choices,
            rawText: input
        )
        return WorkoutCommandExecutionPlan(
            command: .askForConfirmation(confirmation),
            validationResult: .requiresConfirmation(request: confirmation),
            metadata: ParsedCommandMetadata(
                confidence: 0,
                source: .fallback,
                needsConfirmation: true,
                userVisibleSummary: debugReason.map { "Couldn't understand command (\($0))" } ?? "Couldn't understand command"
            )
        )
    }

    private func buildConfirmationChoices(for input: String) -> [CommandConfirmationChoice] {
        let normalized = normalize(input)
        let cleanedExerciseName = cleanedExerciseCandidate(from: input)
        let suggestedSetsCount = extractSuggestedSetCount(from: normalized)

        let addExercise = CommandConfirmationChoice(
            label: "Añadir ejercicio: \(cleanedExerciseName)",
            command: .addExercise(
                AddExerciseCommand(
                    name: cleanedExerciseName,
                    target: .currentWorkout,
                    initialSet: nil,
                    metadata: fallbackMetadata("Clarified: add exercise")
                )
            )
        )

        let addSingleSet = CommandConfirmationChoice(
            label: "Añadir 1 serie al último ejercicio",
            command: .addSet(
                AddSetCommand(
                    target: .lastTouchedExercise,
                    set: ParsedSet(reps: nil, weight: nil, unit: nil),
                    metadata: fallbackMetadata("Clarified: add one set")
                )
            )
        )

        let addMultipleSets = CommandConfirmationChoice(
            label: "Añadir \(suggestedSetsCount) series al último ejercicio",
            command: .addMultipleSets(
                AddMultipleSetsCommand(
                    target: .lastTouchedExercise,
                    sets: Array(repeating: ParsedSet(reps: nil, weight: nil, unit: nil), count: suggestedSetsCount),
                    metadata: fallbackMetadata("Clarified: add multiple sets")
                )
            )
        )

        let duplicateSet = CommandConfirmationChoice(
            label: "Duplicar la última serie",
            command: .duplicateSet(
                DuplicateSetCommand(
                    target: .lastTouchedSet,
                    modifier: nil,
                    metadata: fallbackMetadata("Clarified: duplicate last set")
                )
            )
        )

        let deleteSet = CommandConfirmationChoice(
            label: "Borrar la última serie",
            command: .deleteSet(
                DeleteSetCommand(
                    target: .lastTouchedSet,
                    metadata: fallbackMetadata("Clarified: delete last set")
                )
            )
        )

        if normalized.contains("borra") || normalized.contains("elimina") || normalized.contains("delete") || normalized.contains("remove") {
            return [deleteSet, duplicateSet, addSingleSet, addMultipleSets, addExercise]
        }
        if normalized.contains("serie") || normalized.contains("set") {
            return [addSingleSet, addMultipleSets, duplicateSet, addExercise, deleteSet]
        }
        return [addExercise, addSingleSet, addMultipleSets, duplicateSet, deleteSet]
    }

    private func cleanedExerciseCandidate(from input: String) -> String {
        let cleaned = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^\s*(quiero|hacer|hazme|anade|añade|agrega|pon|add)\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? input : cleaned
    }

    private func extractSuggestedSetCount(from normalized: String) -> Int {
        if let match = normalized.range(of: #"\b(\d+)\s*(series|serie|sets?|set)\b"#, options: .regularExpression) {
            let chunk = String(normalized[match])
            if let n = Int(chunk.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()),
               n > 1, n <= 10 {
                return n
            }
        }

        let tokens: [String: Int] = [
            "dos": 2, "two": 2,
            "tres": 3, "three": 3,
            "cuatro": 4, "four": 4,
            "cinco": 5, "five": 5
        ]
        for (token, count) in tokens where normalized.contains(token) {
            return count
        }
        return 2
    }

    private func fallbackMetadata(_ summary: String) -> ParsedCommandMetadata {
        ParsedCommandMetadata(
            confidence: 0.5,
            source: .fallback,
            needsConfirmation: false,
            userVisibleSummary: summary
        )
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
