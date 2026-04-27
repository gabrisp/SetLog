import CoreData

@MainActor
final class CoreDataWorkoutRepository: WorkoutRepositoryProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchDay(dayKey: String) async throws -> WorkoutDayDTO? {
        let request = WorkoutDay.fetchRequest()
        request.predicate = NSPredicate(format: "dayKey == %@", dayKey)
        request.fetchLimit = 1
        let items = try context.fetch(request)
        return items.first.map(Self.mapDay)
    }

    func createDayIfNeeded(dayKey: String) async throws -> WorkoutDayDTO {
        if let existing = try await fetchDay(dayKey: dayKey) {
            return existing
        }

        let now = Date()
        let day = WorkoutDay(context: context)
        day.id = UUID()
        day.dayKey = dayKey
        day.date = Date.date(fromDayKey: dayKey) ?? now
        day.createdAt = now
        day.updatedAt = now
        try context.save()
        return Self.mapDay(day)
    }

    func fetchWorkoutSessions(dayKey: String) async throws -> [WorkoutSessionDTO] {
        let request = WorkoutSession.fetchRequest()
        request.predicate = NSPredicate(format: "dayKey == %@", dayKey)
        request.sortDescriptors = [
            NSSortDescriptor(key: "orderIndex", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return try context.fetch(request).map(Self.mapSession)
    }

    func createWorkoutSession(dayKey: String, type: String, title: String) async throws -> WorkoutSessionDTO {
        _ = try await createDayIfNeeded(dayKey: dayKey)

        let request = WorkoutSession.fetchRequest()
        request.predicate = NSPredicate(format: "dayKey == %@", dayKey)
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: false)]
        request.fetchLimit = 1
        let maxOrder = try context.fetch(request).first?.orderIndex ?? -1

        let now = Date()
        let session = WorkoutSession(context: context)
        session.id = UUID()
        session.dayKey = dayKey
        session.type = type
        session.title = title
        session.orderIndex = maxOrder + 1
        session.createdAt = now
        session.updatedAt = now
        try context.save()
        return Self.mapSession(session)
    }

    func fetchExercises(workoutSessionID: UUID) async throws -> [ExerciseEntryDTO] {
        let request = ExerciseEntry.fetchRequest()
        request.predicate = NSPredicate(format: "workoutSessionID == %@", workoutSessionID as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(key: "orderIndex", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return try context.fetch(request).map(Self.mapExercise)
    }

    func fetchSets(exerciseEntryID: UUID) async throws -> [WorkoutSetDTO] {
        let request = WorkoutSet.fetchRequest()
        request.predicate = NSPredicate(format: "exerciseEntryID == %@", exerciseEntryID as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(key: "orderIndex", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return try context.fetch(request).map(Self.mapSet)
    }

    func addExercise(toWorkoutSessionID: UUID, name: String, equipment: String?, savedExerciseID: UUID?) async throws -> ExerciseEntryDTO {
        let request = ExerciseEntry.fetchRequest()
        request.predicate = NSPredicate(format: "workoutSessionID == %@", toWorkoutSessionID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: false)]
        request.fetchLimit = 1
        let maxOrder = try context.fetch(request).first?.orderIndex ?? -1

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        let exercise = ExerciseEntry(context: context)
        exercise.id = UUID()
        exercise.workoutSessionID = toWorkoutSessionID
        exercise.savedExerciseID = savedExerciseID
        exercise.name = trimmedName
        exercise.normalizedName = Self.normalize(trimmedName)
        exercise.equipment = equipment?.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.orderIndex = maxOrder + 1
        exercise.createdAt = now
        exercise.updatedAt = now
        try context.save()
        return Self.mapExercise(exercise)
    }

    func addSet(toExerciseEntryID: UUID, reps: Int16, weight: Double, unit: String) async throws -> WorkoutSetDTO {
        let request = WorkoutSet.fetchRequest()
        request.predicate = NSPredicate(format: "exerciseEntryID == %@", toExerciseEntryID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: false)]
        request.fetchLimit = 1
        let maxOrder = try context.fetch(request).first?.orderIndex ?? -1

        let now = Date()
        let set = WorkoutSet(context: context)
        set.id = UUID()
        set.exerciseEntryID = toExerciseEntryID
        set.reps = max(0, reps)
        set.weight = max(0, weight)
        set.unit = unit
        set.rpe = 0
        set.rir = 0
        set.durationSeconds = 0
        set.distanceMeters = 0
        set.isWarmup = false
        set.isFailure = false
        set.orderIndex = maxOrder + 1
        set.createdAt = now
        set.updatedAt = now
        try context.save()
        return Self.mapSet(set)
    }

    func addSet(toExerciseEntryID: UUID, set: WorkoutSetDTO) async throws -> WorkoutSetDTO {
        let request = WorkoutSet.fetchRequest()
        request.predicate = NSPredicate(format: "exerciseEntryID == %@", toExerciseEntryID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: false)]
        request.fetchLimit = 1
        let maxOrder = try context.fetch(request).first?.orderIndex ?? -1

        let now = Date()
        let item = WorkoutSet(context: context)
        item.id = UUID()
        item.exerciseEntryID = toExerciseEntryID
        item.reps = max(0, set.reps)
        item.weight = max(0, set.weight)
        item.unit = set.unit
        item.rpe = set.rpe
        item.rir = set.rir
        item.durationSeconds = set.durationSeconds
        item.distanceMeters = set.distanceMeters
        item.isWarmup = set.isWarmup
        item.isFailure = set.isFailure
        item.notes = set.notes
        item.orderIndex = maxOrder + 1
        item.createdAt = now
        item.updatedAt = now
        try context.save()
        return Self.mapSet(item)
    }

    func duplicateSet(id: UUID, modifier: WorkoutCommandModifier?) async throws -> WorkoutSetDTO {
        guard let original = try fetchSetEntity(id: id) else {
            throw RepositoryError.notFound("WorkoutSet \(id) not found")
        }
        guard let exerciseEntryID = original.exerciseEntryID else {
            throw RepositoryError.notFound("WorkoutSet \(id) is missing exercise reference")
        }

        let request = WorkoutSet.fetchRequest()
        request.predicate = NSPredicate(format: "exerciseEntryID == %@", exerciseEntryID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: false)]
        request.fetchLimit = 1
        let maxOrder = try context.fetch(request).first?.orderIndex ?? -1

        let now = Date()
        let copy = WorkoutSet(context: context)
        copy.id = UUID()
        copy.exerciseEntryID = exerciseEntryID
        copy.reps = max(0, original.reps + Int16(modifier?.repsDelta ?? 0))
        copy.weight = max(0, original.weight + (modifier?.weightDelta ?? 0))
        copy.unit = original.unit ?? "kg"
        copy.rpe = original.rpe
        copy.rir = original.rir
        copy.durationSeconds = Int32(max(0, Int(original.durationSeconds) + (modifier?.durationDeltaSeconds ?? 0)))
        copy.distanceMeters = max(0, original.distanceMeters + (modifier?.distanceDeltaMeters ?? 0))
        copy.isWarmup = modifier?.markAsWarmup ?? original.isWarmup
        copy.isFailure = modifier?.markAsFailure ?? original.isFailure
        copy.notes = original.notes
        copy.orderIndex = maxOrder + 1
        copy.createdAt = now
        copy.updatedAt = now
        try context.save()
        return Self.mapSet(copy)
    }

    func deleteSet(id: UUID) async throws {
        guard let set = try fetchSetEntity(id: id) else {
            throw RepositoryError.notFound("WorkoutSet \(id) not found")
        }
        context.delete(set)
        try context.save()
    }

    func updateSet(id: UUID, reps: Int16?, weight: Double?, notes: String?) async throws {
        guard let set = try fetchSetEntity(id: id) else {
            throw RepositoryError.notFound("WorkoutSet \(id) not found")
        }

        if let reps {
            set.reps = max(0, reps)
        }
        if let weight {
            set.weight = max(0, weight)
        }
        if let notes {
            set.notes = notes
        }
        set.updatedAt = Date()
        try context.save()
    }

    func updateExercise(id: UUID, name: String?, notes: String?) async throws {
        guard let exercise = try fetchExerciseEntity(id: id) else {
            throw RepositoryError.notFound("ExerciseEntry \(id) not found")
        }

        if let name {
            exercise.name = name
            exercise.normalizedName = Self.normalize(name)
        }
        if let notes {
            exercise.notes = notes
        }
        exercise.updatedAt = Date()
        try context.save()
    }

    func moveExercise(id: UUID, toIndex: Int) async throws {
        guard let moving = try fetchExerciseEntity(id: id) else {
            throw RepositoryError.notFound("ExerciseEntry \(id) not found")
        }
        guard let workoutSessionID = moving.workoutSessionID else {
            throw RepositoryError.notFound("ExerciseEntry \(id) is missing session reference")
        }

        let request = ExerciseEntry.fetchRequest()
        request.predicate = NSPredicate(format: "workoutSessionID == %@", workoutSessionID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        var items = try context.fetch(request)
        guard let from = items.firstIndex(where: { $0.id == id }) else { return }

        let target = max(0, min(toIndex, items.count - 1))
        let item = items.remove(at: from)
        items.insert(item, at: target)

        let now = Date()
        for (index, exercise) in items.enumerated() {
            exercise.orderIndex = Int16(index)
            exercise.updatedAt = now
        }
        try context.save()
    }

    func fetchToday() async throws -> WorkoutDayDTO? {
        try await fetchDay(dayKey: Date.todayDayKey)
    }

    // MARK: - Helpers

    private func fetchExerciseEntity(id: UUID) throws -> ExerciseEntry? {
        let request = ExerciseEntry.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchSetEntity(id: UUID) throws -> WorkoutSet? {
        let request = WorkoutSet.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func mapDay(_ day: WorkoutDay) -> WorkoutDayDTO {
        WorkoutDayDTO(
            id: day.id ?? UUID(),
            dayKey: day.dayKey ?? "",
            date: day.date ?? Date(),
            createdAt: day.createdAt ?? Date(),
            updatedAt: day.updatedAt ?? Date()
        )
    }

    private static func mapSession(_ session: WorkoutSession) -> WorkoutSessionDTO {
        WorkoutSessionDTO(
            id: session.id ?? UUID(),
            dayKey: session.dayKey ?? "",
            title: session.title ?? "",
            type: session.type ?? "strength",
            orderIndex: session.orderIndex,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            notes: session.notes,
            createdAt: session.createdAt ?? Date(),
            updatedAt: session.updatedAt ?? Date()
        )
    }

    private static func mapExercise(_ exercise: ExerciseEntry) -> ExerciseEntryDTO {
        ExerciseEntryDTO(
            id: exercise.id ?? UUID(),
            workoutSessionID: exercise.workoutSessionID ?? UUID(),
            savedExerciseID: exercise.savedExerciseID,
            name: exercise.name ?? "",
            normalizedName: exercise.normalizedName ?? "",
            equipment: exercise.equipment,
            primaryMusclesText: exercise.primaryMusclesText,
            secondaryMusclesText: exercise.secondaryMusclesText,
            orderIndex: exercise.orderIndex,
            notes: exercise.notes,
            createdAt: exercise.createdAt ?? Date(),
            updatedAt: exercise.updatedAt ?? Date()
        )
    }

    private static func mapSet(_ set: WorkoutSet) -> WorkoutSetDTO {
        WorkoutSetDTO(
            id: set.id ?? UUID(),
            exerciseEntryID: set.exerciseEntryID ?? UUID(),
            reps: set.reps,
            weight: set.weight,
            unit: set.unit ?? "kg",
            rpe: set.rpe,
            rir: set.rir,
            durationSeconds: set.durationSeconds,
            distanceMeters: set.distanceMeters,
            isWarmup: set.isWarmup,
            isFailure: set.isFailure,
            orderIndex: set.orderIndex,
            notes: set.notes,
            createdAt: set.createdAt ?? Date(),
            updatedAt: set.updatedAt ?? Date()
        )
    }

    private static func normalize(_ name: String) -> String {
        name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private enum RepositoryError: Error, LocalizedError {
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let message):
            return message
        }
    }
}
