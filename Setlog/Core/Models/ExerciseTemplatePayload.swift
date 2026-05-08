import Foundation

struct ExerciseTemplatePayload: Codable {
    var name: String
    var equipment: String?
    var isUnilateral: Bool
    var primaryMusclesText: String?
    var secondaryMusclesText: String?
    var sets: [ExerciseTemplateSetPayload]
}

struct ExerciseTemplateSetPayload: Codable {
    var reps: Int16
    var weight: Double
    var unit: String
    var side: String?
    var notes: String?
    var isWarmup: Bool
    var isFailure: Bool
    var durationSeconds: Int32?
}
