import CoreData

final class CoreDataRecentItemsRepository: RecentItemsRepositoryProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func saveRecentSnippet(title: String, payloadJSON: String, snippetType: String, sourceDayKey: String?) async throws {
        try await context.perform {
            let now = Date()
            let snippet = RecentWorkoutSnippet(context: self.context)
            snippet.id = UUID()
            snippet.title = title
            snippet.normalizedTitle = Self.normalize(title)
            snippet.payloadJSON = payloadJSON
            snippet.snippetType = snippetType
            snippet.createdAt = now
            snippet.lastUsedAt = now
            snippet.useCount = 1
            snippet.decayScore = 1
            snippet.sourceDayKey = sourceDayKey
            try self.context.save()
        }
    }

    func fetchRecentSnippets(limit: Int) async throws -> [RecentWorkoutSnippetDTO] {
        try await context.perform {
            let request = RecentWorkoutSnippet.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "decayScore", ascending: false),
                NSSortDescriptor(key: "lastUsedAt", ascending: false),
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            request.fetchLimit = limit

            return try self.context.fetch(request).map { item in
                RecentWorkoutSnippetDTO(
                    id: item.id ?? UUID(),
                    title: item.title ?? "",
                    normalizedTitle: item.normalizedTitle ?? "",
                    payloadJSON: item.payloadJSON ?? "{}",
                    snippetType: item.snippetType ?? "command",
                    createdAt: item.createdAt ?? Date(),
                    lastUsedAt: item.lastUsedAt,
                    useCount: item.useCount,
                    decayScore: item.decayScore,
                    sourceDayKey: item.sourceDayKey,
                    sourceWorkoutSessionID: item.sourceWorkoutSessionID,
                    sourceExerciseEntryID: item.sourceExerciseEntryID
                )
            }
        }
    }

    func markRecentUsed(id: UUID) async throws {
        try await context.perform {
            let request = RecentWorkoutSnippet.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let snippet = try self.context.fetch(request).first else { return }

            let now = Date()
            snippet.useCount += 1
            snippet.lastUsedAt = now
            snippet.decayScore = Self.decayScore(useCount: snippet.useCount, lastUsedAt: now)
            try self.context.save()
        }
    }

    func clearRecents() async throws {
        try await context.perform {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "RecentWorkoutSnippet")
            let delete = NSBatchDeleteRequest(fetchRequest: request)
            delete.resultType = .resultTypeObjectIDs

            if let result = try self.context.execute(delete) as? NSBatchDeleteResult,
               let objectIDs = result.result as? [NSManagedObjectID] {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.context])
            }
        }
    }

    func pruneOldRecents() async throws {
        try await context.perform {
            let cutoff = Calendar.current.date(byAdding: .day, value: -45, to: Date()) ?? .distantPast
            let request = RecentWorkoutSnippet.fetchRequest()
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "createdAt < %@", cutoff as NSDate),
                NSPredicate(format: "decayScore < %lf", 0.2)
            ])
            let stale = try self.context.fetch(request)
            stale.forEach(self.context.delete)
            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func decayScore(useCount: Int32, lastUsedAt: Date) -> Double {
        let ageHours = max(1, Date().timeIntervalSince(lastUsedAt) / 3600)
        return Double(useCount) / pow(ageHours, 0.25)
    }
}
