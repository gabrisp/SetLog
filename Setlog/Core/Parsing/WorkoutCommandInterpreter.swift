import Foundation

final class WorkoutCommandInterpreter {

    private let localParser: LocalWorkoutCommandParser
    private let foundationModelsParser: FoundationModelsWorkoutCommandParser
    private let entitlementService: EntitlementServiceProtocol
    private static let afmPreferredConfidence: Double = 0.78

    init(
        localParser: LocalWorkoutCommandParser = LocalWorkoutCommandParser(),
        entitlementService: EntitlementServiceProtocol
    ) {
        self.localParser = localParser
        self.foundationModelsParser = FoundationModelsWorkoutCommandParser(entitlementService: entitlementService)
        self.entitlementService = entitlementService
    }

    func interpret(input: String, context: WorkoutCommandContext) async -> WorkoutCommandExecutionPlan {
        // Access is intentionally enabled for all users in this slice.
        // Keep entitlement service around so we can re-enable gating later.
        _ = entitlementService

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
                let userFacingReason = fmReason.lowercased().contains("unsupportedlanguageorlocale")
                    ? "AFM couldn't parse this locale/input and local fallback also failed."
                    : "Couldn't understand command with AFM or local fallback."
                return WorkoutCommandExecutionPlan(
                    command: .unknown(rawText: input),
                    validationResult: .invalid(reason: userFacingReason),
                    metadata: ParsedCommandMetadata(
                        confidence: 0,
                        source: .fallback,
                        needsConfirmation: true,
                        userVisibleSummary: "AFM + local fallback failed (\(fmReason))"
                    )
                )
            }
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
        if shouldPreferLocal(for: input, fmPlan: fmPlan, localPlan: localPlan) {
            return localPlan
        }

        if fmPlan.metadata.confidence >= Self.afmPreferredConfidence {
            return fmPlan
        }

        if localPlan.metadata.confidence > fmPlan.metadata.confidence {
            return localPlan
        }

        return fmPlan
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

        let normalized = trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        let blocked = ["borra", "elimina", "delete", "remove", "clear", "settings", "calendar", "ajustes", "calendario"]
        guard !blocked.contains(where: normalized.contains) else { return nil }

        let cleaned = trimmed
            .replacingOccurrences(of: #"^\s*(quiero|hacer|hazme|anade|añade|add)\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count >= 3 else { return nil }

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

    private func buildConfirmationPlan(for input: String) -> WorkoutCommandExecutionPlan {
        let confirmation = CommandConfirmationRequest(
            prompt: "I couldn't understand \"\(input)\". Try rephrasing the command.",
            choices: [],
            rawText: input
        )
        return WorkoutCommandExecutionPlan(
            command: .askForConfirmation(confirmation),
            validationResult: .requiresConfirmation(request: confirmation),
            metadata: ParsedCommandMetadata(
                confidence: 0,
                source: .fallback,
                needsConfirmation: true,
                userVisibleSummary: "Couldn't understand command"
            )
        )
    }
}
