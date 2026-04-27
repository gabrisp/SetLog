import Foundation

struct WorkoutCommandExecutionPlan {
    var command: ParsedWorkoutCommand
    var validationResult: WorkoutCommandValidationResult
    var metadata: ParsedCommandMetadata
}
