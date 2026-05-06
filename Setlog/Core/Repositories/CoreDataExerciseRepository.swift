import CoreData

@MainActor
final class CoreDataExerciseRepository: ExerciseRepositoryProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchSavedExercises() async throws -> [SavedExerciseDTO] {
        try await context.perform {
            let request = SavedExercise.fetchRequest()
            request.predicate = NSPredicate(format: "isArchived == NO")
            request.sortDescriptors = [
                NSSortDescriptor(key: "lastUsedAt", ascending: false),
                NSSortDescriptor(key: "useCount", ascending: false),
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            return try self.context.fetch(request).map { Self.mapSaved($0) }
        }
    }

    func fetchSavedExercise(id: UUID) async throws -> SavedExerciseDTO? {
        try await context.perform {
            let request = SavedExercise.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let item = try self.context.fetch(request).first else { return nil }
            return Self.mapSaved(item)
        }
    }

    func createSavedExercise(name: String, equipment: String?) async throws -> SavedExerciseDTO {
        try await context.perform {
            let now = Date()
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedEquipment = equipment?.trimmingCharacters(in: .whitespacesAndNewlines)

            let entity = SavedExercise(context: self.context)
            entity.id = UUID()
            entity.name = trimmedName
            entity.normalizedName = Self.normalize(trimmedName)
            entity.equipment = trimmedEquipment?.isEmpty == false ? trimmedEquipment : nil
            entity.createdAt = now
            entity.updatedAt = now
            entity.lastUsedAt = now
            entity.useCount = 0
            entity.isArchived = false

            try self.context.save()
            return Self.mapSaved(entity)
        }
    }

    func updateSavedExercise(
        id: UUID,
        name: String?,
        equipment: String?,
        primaryMusclesText: String?,
        secondaryMusclesText: String?,
        aiPrimaryMusclesText: String?,
        aiSecondaryMusclesText: String?
    ) async throws {
        try await context.perform {
            let request = SavedExercise.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try self.context.fetch(request).first else { return }

            if let name {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    entity.name = trimmed
                    entity.normalizedName = Self.normalize(trimmed)
                }
            }

            if let equipment {
                let trimmed = equipment.trimmingCharacters(in: .whitespacesAndNewlines)
                entity.equipment = trimmed.isEmpty ? nil : trimmed
            }

            if let primaryMusclesText {
                let trimmed = primaryMusclesText.trimmingCharacters(in: .whitespacesAndNewlines)
                entity.primaryMusclesText = trimmed.isEmpty ? nil : trimmed
            }

            if let secondaryMusclesText {
                let trimmed = secondaryMusclesText.trimmingCharacters(in: .whitespacesAndNewlines)
                entity.secondaryMusclesText = trimmed.isEmpty ? nil : trimmed
            }

            if let aiPrimaryMusclesText {
                let trimmed = aiPrimaryMusclesText.trimmingCharacters(in: .whitespacesAndNewlines)
                entity.aiPrimaryMusclesText = trimmed.isEmpty ? nil : trimmed
            }

            if let aiSecondaryMusclesText {
                let trimmed = aiSecondaryMusclesText.trimmingCharacters(in: .whitespacesAndNewlines)
                entity.aiSecondaryMusclesText = trimmed.isEmpty ? nil : trimmed
            }

            entity.updatedAt = Date()
            try self.context.save()
        }
    }

    func archiveSavedExercise(id: UUID) async throws {
        try await context.perform {
            let request = SavedExercise.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try self.context.fetch(request).first else { return }
            entity.isArchived = true
            entity.updatedAt = Date()
            try self.context.save()
        }
    }

    func markUsed(id: UUID) async throws {
        try await context.perform {
            let request = SavedExercise.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try self.context.fetch(request).first else { return }
            entity.useCount += 1
            entity.lastUsedAt = Date()
            entity.updatedAt = Date()
            try self.context.save()
        }
    }

    func createFavoriteSnippet(savedExerciseID: UUID, title: String, payloadJSON: String, snippetType: String) async throws -> FavoriteWorkoutSnippetDTO {
        try await context.perform {
            let now = Date()
            let request = FavoriteWorkoutSnippet.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "savedExerciseID == %@", savedExerciseID as CVarArg),
                NSPredicate(format: "snippetType == %@", snippetType)
            ])
            request.fetchLimit = 1

            let entity: FavoriteWorkoutSnippet
            if let existing = try self.context.fetch(request).first {
                entity = existing
                entity.updatedAt = now
                entity.lastUsedAt = now
                entity.useCount += 1
            } else {
                entity = FavoriteWorkoutSnippet(context: self.context)
                entity.id = UUID()
                entity.savedExerciseID = savedExerciseID
                entity.snippetType = snippetType
                entity.createdAt = now
                entity.updatedAt = now
                entity.lastUsedAt = now
                entity.useCount = 0
            }

            entity.title = title
            entity.payloadJSON = payloadJSON
            try self.context.save()
            return Self.mapFavorite(entity)
        }
    }

    func fetchFavoriteSnippets() async throws -> [FavoriteWorkoutSnippetDTO] {
        try await context.perform {
            let request = FavoriteWorkoutSnippet.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "lastUsedAt", ascending: false),
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            return try self.context.fetch(request).map { Self.mapFavorite($0) }
        }
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func mapSaved(_ item: SavedExercise) -> SavedExerciseDTO {
        SavedExerciseDTO(
            id: item.id ?? UUID(),
            name: item.name ?? "",
            normalizedName: item.normalizedName ?? "",
            imageFileName: item.imageFileName,
            primaryMusclesText: item.primaryMusclesText,
            secondaryMusclesText: item.secondaryMusclesText,
            aiPrimaryMusclesText: item.aiPrimaryMusclesText,
            aiSecondaryMusclesText: item.aiSecondaryMusclesText,
            equipment: item.equipment,
            descriptionText: item.descriptionText,
            instructionsText: item.instructionsText,
            createdAt: item.createdAt ?? Date(),
            updatedAt: item.updatedAt ?? Date(),
            lastUsedAt: item.lastUsedAt,
            useCount: item.useCount,
            isArchived: item.isArchived
        )
    }

    private static func mapFavorite(_ item: FavoriteWorkoutSnippet) -> FavoriteWorkoutSnippetDTO {
        FavoriteWorkoutSnippetDTO(
            id: item.id ?? UUID(),
            savedExerciseID: item.savedExerciseID ?? UUID(),
            title: item.title ?? "",
            payloadJSON: item.payloadJSON ?? "{}",
            snippetType: item.snippetType ?? "exercise",
            createdAt: item.createdAt ?? Date(),
            updatedAt: item.updatedAt ?? Date(),
            lastUsedAt: item.lastUsedAt,
            useCount: item.useCount
        )
    }
}
