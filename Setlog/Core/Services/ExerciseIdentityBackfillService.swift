import CoreData
import Foundation

@MainActor
final class ExerciseIdentityBackfillService {

    private enum Keys {
        static let hasCompletedBackfill = "exercise_identity_backfill_v1_completed"
    }

    private let context: NSManagedObjectContext
    private let resolver: ExerciseIdentityResolver
    private let defaults: UserDefaults

    init(
        context: NSManagedObjectContext,
        resolver: ExerciseIdentityResolver,
        defaults: UserDefaults = .standard
    ) {
        self.context = context
        self.resolver = resolver
        self.defaults = defaults
    }

    func runIfNeeded() async {
        if defaults.bool(forKey: Keys.hasCompletedBackfill) {
            return
        }

        do {
            let request = ExerciseEntry.fetchRequest()
            request.predicate = NSPredicate(format: "savedExerciseID == nil")
            let entries = try context.fetch(request)

            guard !entries.isEmpty else {
                defaults.set(true, forKey: Keys.hasCompletedBackfill)
                return
            }

            for entry in entries {
                guard let id = entry.id else { continue }
                let name = (entry.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }

                let resolution = try await resolver.resolve(
                    rawInput: name,
                    hintedExerciseName: name,
                    hintedEquipment: entry.equipment,
                    aiPrimaryMusclesText: entry.primaryMusclesText,
                    aiSecondaryMusclesText: entry.secondaryMusclesText
                )

                if let managed = try fetchExerciseEntry(id: id) {
                    managed.savedExerciseID = resolution.savedExerciseID
                    if (managed.primaryMusclesText ?? "").isEmpty {
                        managed.primaryMusclesText = resolution.primaryMusclesText
                    }
                    if (managed.secondaryMusclesText ?? "").isEmpty {
                        managed.secondaryMusclesText = resolution.secondaryMusclesText
                    }
                    managed.updatedAt = Date()
                }
            }

            if context.hasChanges {
                try context.save()
            }

            defaults.set(true, forKey: Keys.hasCompletedBackfill)
        } catch {
            // Keep app startup resilient. Backfill will retry next launch.
        }
    }

    private func fetchExerciseEntry(id: UUID) throws -> ExerciseEntry? {
        let request = ExerciseEntry.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
