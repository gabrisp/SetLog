import Foundation

final class WorkoutCommandInterpreter {

    private let localParser: LocalWorkoutCommandParser
    private let foundationModelsParser: FoundationModelsWorkoutCommandParser
    private let entitlementService: EntitlementServiceProtocol

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

        // 1) Foundation Models first.
        let fmPlan = await foundationModelsParser.parse(input: input, context: context)
        if case .valid = fmPlan.validationResult {
            return fmPlan
        }

        // 2) Local parser fallback only when Foundation Models cannot return a valid command.
        let localPlan = await localParser.parse(input: input, context: context)
        if case .valid = localPlan.validationResult {
            return localPlan
        }

        // 3) Keep FM result when it is explicit about gating/confirmation.
        switch fmPlan.validationResult {
        case .requiresConfirmation, .requiresProFeature:
            return fmPlan
        case .valid, .invalid:
            break
        }

        // 4) Unknown fallback.
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
