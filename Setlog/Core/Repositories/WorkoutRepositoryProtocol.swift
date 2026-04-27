import Foundation

// MARK: - DTOs (plain structs, never NSManagedObject)

struct WorkoutDayDTO {
    var id: UUID
    var dayKey: String
    var date: Date
    var createdAt: Date
    var updatedAt: Date
}

struct WorkoutSessionDTO {
    var id: UUID
    var dayKey: String
    var title: String
    var type: String
    var orderIndex: Int16
    var startedAt: Date?
    var endedAt: Date?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
}

struct ExerciseEntryDTO {
    var id: UUID
    var workoutSessionID: UUID
    var savedExerciseID: UUID?
    var name: String
    var normalizedName: String
    var equipment: String?
    var primaryMusclesText: String?
    var secondaryMusclesText: String?
    var orderIndex: Int16
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
}

struct WorkoutSetDTO {
    var id: UUID
    var exerciseEntryID: UUID
    var reps: Int16
    var weight: Double
    var unit: String
    var rpe: Double
    var rir: Int16
    var durationSeconds: Int32
    var distanceMeters: Double
    var isWarmup: Bool
    var isFailure: Bool
    var orderIndex: Int16
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
}

// MARK: - Protocol

protocol WorkoutRepositoryProtocol {
    func fetchDay(dayKey: String) async throws -> WorkoutDayDTO?
    func createDayIfNeeded(dayKey: String) async throws -> WorkoutDayDTO
    func fetchWorkoutSessions(dayKey: String) async throws -> [WorkoutSessionDTO]
    func createWorkoutSession(dayKey: String, type: String, title: String) async throws -> WorkoutSessionDTO
    func addExercise(toWorkoutSessionID: UUID, name: String, savedExerciseID: UUID?) async throws -> ExerciseEntryDTO
    func addSet(toExerciseEntryID: UUID, set: WorkoutSetDTO) async throws -> WorkoutSetDTO
    func duplicateSet(id: UUID, modifier: WorkoutCommandModifier?) async throws -> WorkoutSetDTO
    func deleteSet(id: UUID) async throws
    func updateSet(id: UUID, reps: Int16?, weight: Double?, notes: String?) async throws
    func updateExercise(id: UUID, name: String?, notes: String?) async throws
    func moveExercise(id: UUID, toIndex: Int) async throws
    func fetchToday() async throws -> WorkoutDayDTO?
}
