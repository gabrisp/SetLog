import Foundation

// MARK: - Command types

enum ParsedWorkoutCommand {
    case addExercise(AddExerciseCommand)
    case addSet(AddSetCommand)
    case addMultipleSets(AddMultipleSetsCommand)
    case duplicateSet(DuplicateSetCommand)
    case updateSet(UpdateSetCommand)
    case deleteSet(DeleteSetCommand)
    case saveExerciseAsFavorite(SaveExerciseAsFavoriteCommand)
    case saveSetAsFavorite(SaveSetAsFavoriteCommand)
    case addFavoriteToWorkout(AddFavoriteToWorkoutCommand)
    case addRecentToWorkout(AddRecentToWorkoutCommand)
    case startWorkoutSession(StartWorkoutSessionCommand)
    case switchWorkoutSession(SwitchWorkoutSessionCommand)
    case askForConfirmation(CommandConfirmationRequest)
    case unknown(rawText: String)
}

// MARK: - Target

enum WorkoutCommandTarget {
    case currentWorkout
    case workoutSession(id: UUID)
    case exercise(id: UUID)
    case exerciseName(String)
    case savedExercise(id: UUID)
    case recentSnippet(id: UUID)
    case lastTouchedExercise
    case lastTouchedSet
    case previousExercise
    case selectedExercise
}

// MARK: - Modifier

struct WorkoutCommandModifier {
    var weightDelta: Double?
    var repsDelta: Int?
    var durationDeltaSeconds: Int?
    var distanceDeltaMeters: Double?
    var markAsFailure: Bool?
    var markAsWarmup: Bool?
}

// MARK: - Metadata

enum ParserSource {
    case localParser
    case foundationModels
    case manual
    case fallback
}

struct ParsedCommandMetadata {
    var confidence: Double           // 0.0–1.0
    var source: ParserSource
    var needsConfirmation: Bool
    var userVisibleSummary: String
}

// MARK: - Parsed set

struct ParsedSet {
    var reps: Int?
    var weight: Double?
    var unit: String?                // "kg" / "lb" / "bodyweight"
    var rpe: Double?
    var rir: Int?
    var durationSeconds: Int?
    var distanceMeters: Double?
    var isWarmup: Bool?
    var isFailure: Bool?
    var notes: String?
}

// MARK: - Individual command structs

struct AddExerciseCommand {
    var name: String
    var target: WorkoutCommandTarget
    var initialSet: ParsedSet?
    var metadata: ParsedCommandMetadata
}

struct AddSetCommand {
    var target: WorkoutCommandTarget
    var set: ParsedSet
    var metadata: ParsedCommandMetadata
}

struct AddMultipleSetsCommand {
    var target: WorkoutCommandTarget
    var sets: [ParsedSet]
    var metadata: ParsedCommandMetadata
}

struct DuplicateSetCommand {
    var target: WorkoutCommandTarget
    var modifier: WorkoutCommandModifier?
    var metadata: ParsedCommandMetadata
}

struct UpdateSetCommand {
    var target: WorkoutCommandTarget
    var modifier: WorkoutCommandModifier
    var metadata: ParsedCommandMetadata
}

struct DeleteSetCommand {
    var target: WorkoutCommandTarget
    var metadata: ParsedCommandMetadata
}

struct SaveExerciseAsFavoriteCommand {
    var target: WorkoutCommandTarget
    var title: String?
    var metadata: ParsedCommandMetadata
}

struct SaveSetAsFavoriteCommand {
    var target: WorkoutCommandTarget
    var title: String?
    var metadata: ParsedCommandMetadata
}

struct AddFavoriteToWorkoutCommand {
    var snippetID: UUID
    var metadata: ParsedCommandMetadata
}

struct AddRecentToWorkoutCommand {
    var snippetID: UUID
    var metadata: ParsedCommandMetadata
}

struct StartWorkoutSessionCommand {
    var type: String
    var title: String?
    var metadata: ParsedCommandMetadata
}

struct SwitchWorkoutSessionCommand {
    var sessionID: UUID
    var metadata: ParsedCommandMetadata
}

// MARK: - Confirmation

struct CommandConfirmationChoice {
    var label: String
    var command: ParsedWorkoutCommand
}

struct CommandConfirmationRequest {
    var prompt: String
    var choices: [CommandConfirmationChoice]
    var rawText: String
    var generatedQuestion: String? // FM-generated question shown prominently in the clarification sheet
}
