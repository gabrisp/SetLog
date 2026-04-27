import Foundation

protocol WorkoutCommandParsingService {
    func parse(input: String, context: WorkoutCommandContext) async -> WorkoutCommandExecutionPlan
}
