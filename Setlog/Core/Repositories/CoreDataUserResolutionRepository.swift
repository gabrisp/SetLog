import CoreData

final class CoreDataUserResolutionRepository: UserResolutionRepositoryProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func save(rawInput: String, resolvedExerciseName: String, resolvedIntent: String) async throws {
        try await context.perform {
            // Update existing if same rawInput already known
            let request = UserCommandResolution.fetchRequest()
            request.predicate = NSPredicate(format: "rawInput == %@", rawInput)
            request.fetchLimit = 1

            if let existing = try self.context.fetch(request).first {
                existing.resolvedExerciseName = resolvedExerciseName
                existing.resolvedIntent = resolvedIntent
                existing.useCount += 1
                existing.lastUsedAt = Date()
            } else {
                let entity = UserCommandResolution(context: self.context)
                entity.id = UUID()
                entity.rawInput = rawInput
                entity.resolvedExerciseName = resolvedExerciseName
                entity.resolvedIntent = resolvedIntent
                entity.useCount = 1
                entity.createdAt = Date()
                entity.lastUsedAt = Date()
            }
            try self.context.save()
        }
    }

    func findAll() async throws -> [UserCommandResolutionDTO] {
        try await context.perform {
            let request = UserCommandResolution.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "useCount", ascending: false)]
            return try self.context.fetch(request).map { e in
                UserCommandResolutionDTO(
                    id: e.id ?? UUID(),
                    rawInput: e.rawInput ?? "",
                    resolvedExerciseName: e.resolvedExerciseName ?? "",
                    resolvedIntent: e.resolvedIntent ?? "add_set",
                    useCount: Int(e.useCount),
                    lastUsedAt: e.lastUsedAt ?? Date(),
                    createdAt: e.createdAt ?? Date()
                )
            }
        }
    }

    func incrementUseCount(id: UUID) async throws {
        try await context.perform {
            let request = UserCommandResolution.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try self.context.fetch(request).first {
                entity.useCount += 1
                entity.lastUsedAt = Date()
                try self.context.save()
            }
        }
    }

    func delete(id: UUID) async throws {
        try await context.perform {
            let request = UserCommandResolution.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try self.context.fetch(request).first {
                self.context.delete(entity)
                try self.context.save()
            }
        }
    }
}
