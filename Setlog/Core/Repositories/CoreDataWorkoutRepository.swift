import CoreData

final class CoreDataWorkoutRepository: WorkoutRepositoryProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchDay(dayKey: String) async throws -> WorkoutDayDTO? {
        // TODO: NSFetchRequest<WorkoutDay> filtered by dayKey
        return nil
    }

    func createDayIfNeeded(dayKey: String) async throws -> WorkoutDayDTO {
        fatalError("TODO: implement createDayIfNeeded")
    }

    func fetchWorkoutSessions(dayKey: String) async throws -> [WorkoutSessionDTO] {
        // TODO: NSFetchRequest<WorkoutSession> filtered by dayKey, sorted by orderIndex
        return []
    }

    func createWorkoutSession(dayKey: String, type: String, title: String) async throws -> WorkoutSessionDTO {
        fatalError("TODO: implement createWorkoutSession")
    }

    func addExercise(toWorkoutSessionID: UUID, name: String, savedExerciseID: UUID?) async throws -> ExerciseEntryDTO {
        fatalError("TODO: implement addExercise")
    }

    func addSet(toExerciseEntryID: UUID, set: WorkoutSetDTO) async throws -> WorkoutSetDTO {
        fatalError("TODO: implement addSet")
    }

    func duplicateSet(id: UUID, modifier: WorkoutCommandModifier?) async throws -> WorkoutSetDTO {
        fatalError("TODO: implement duplicateSet")
    }

    func deleteSet(id: UUID) async throws {
        // TODO: fetch WorkoutSet by id, delete, save context
    }

    func updateSet(id: UUID, reps: Int16?, weight: Double?, notes: String?) async throws {
        // TODO: fetch WorkoutSet by id, apply updates, save context
    }

    func updateExercise(id: UUID, name: String?, notes: String?) async throws {
        // TODO: fetch ExerciseEntry by id, apply updates, save context
    }

    func moveExercise(id: UUID, toIndex: Int) async throws {
        // TODO: reorder ExerciseEntry.orderIndex within its WorkoutSession
    }

    func fetchToday() async throws -> WorkoutDayDTO? {
        return try await fetchDay(dayKey: Date.todayDayKey)
    }
}
