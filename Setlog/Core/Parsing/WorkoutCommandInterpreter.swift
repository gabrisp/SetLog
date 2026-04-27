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

    func interpret(input: String, context: WorkoutCommandContext) -> WorkoutCommandExecutionPlan {
        // 1. Try local parser first
        let localPlan = localParser.parse(input: input, context: context)

        // 2. If local confidence is high enough, use it directly
        if localPlan.metadata.confidence >= Self.localConfidenceThreshold {
            return localPlan
        }

        // 3. If command is complex / low confidence, attempt Foundation Models
        // TODO: When FM is available and user is Pro, call foundationModelsParser
        // if entitlementService.canUse(.aiCommandParsing) {
        //     let fmPlan = foundationModelsParser.parse(input: input, context: context)
        //     if fmPlan.metadata.confidence >= Self.localConfidenceThreshold { return fmPlan }
        // }

        // 4. If local result is .unknown, build a confirmation request
        if case .unknown = localPlan.command {
            let confirmation = CommandConfirmationRequest(
                prompt: "I didn't understand \"\(input)\". Try rephrasing or pick an action:",
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

        // 5. Return local result even at lower confidence (needsConfirmation = true)
        return localPlan
    }
}
