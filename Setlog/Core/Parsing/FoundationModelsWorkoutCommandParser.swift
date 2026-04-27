import Foundation

// TODO: Implement using Apple Foundation Models API (iOS 26+, available when on-device model ships).
// This service must only return structured ParsedWorkoutCommand values — never prose.
// It must never directly mutate Core Data. All mutations go through ViewModels and repositories.
// Check entitlementService.canUse(.aiCommandParsing) before invoking the model.
final class FoundationModelsWorkoutCommandParser: WorkoutCommandParsingService {

    private let entitlementService: EntitlementServiceProtocol

    init(entitlementService: EntitlementServiceProtocol) {
        self.entitlementService = entitlementService
    }

    func parse(input: String, context: WorkoutCommandContext) -> WorkoutCommandExecutionPlan {
        // TODO: Check entitlement
        // guard entitlementService.canUse(.aiCommandParsing) else {
        //     return proGatePlan(input: input)
        // }

        // TODO: Invoke Apple Foundation Models API
        // let session = LanguageModelSession(...)
        // let response = try await session.respond(to: prompt)
        // let command = parseStructuredResponse(response)

        return WorkoutCommandExecutionPlan(
            command: .unknown(rawText: input),
            validationResult: .invalid(reason: "Foundation Models not yet implemented"),
            metadata: ParsedCommandMetadata(
                confidence: 0,
                source: .foundationModels,
                needsConfirmation: false,
                userVisibleSummary: ""
            )
        )
    }
}
