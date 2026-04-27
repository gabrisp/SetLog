import Foundation

final class WorkoutCommandInterpreter {

    private let localParser: LocalWorkoutCommandParser
    private let foundationModelsParser: FoundationModelsWorkoutCommandParser
    private let entitlementService: EntitlementServiceProtocol

    private static let localConfidenceThreshold: Double = 0.75

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
        if isHighConfidenceValid(fmPlan) {
            return fmPlan
        }

        // 2) Local parser fallback.
        let localPlan = await localParser.parse(input: input, context: context)
        if case .valid = localPlan.validationResult {
            return localPlan
        }

        // 3) If FM is valid but low-confidence, still prefer it over unknown.
        if case .valid = fmPlan.validationResult {
            return fmPlan
        }

        // 4) Unknown fallback confirmation request.
        if case .unknown = localPlan.command {
            return buildConfirmationPlan(for: input)
        }

        return localPlan
    }

    private func isHighConfidenceValid(_ plan: WorkoutCommandExecutionPlan) -> Bool {
        guard case .valid = plan.validationResult else { return false }
        return plan.metadata.confidence >= Self.localConfidenceThreshold
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
