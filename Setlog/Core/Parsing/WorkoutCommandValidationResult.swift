import Foundation

enum WorkoutCommandValidationResult {
    case valid
    case invalid(reason: String)
    case requiresConfirmation(request: CommandConfirmationRequest)
    case requiresProFeature(feature: ProFeature)
}
