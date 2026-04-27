import CoreData

final class CoreDataRecentItemsRepository: RecentItemsRepositoryProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func saveRecentSnippet(title: String, payloadJSON: String, snippetType: String, sourceDayKey: String?) async throws {
        // TODO: Create RecentWorkoutSnippet entity, set fields, save context
    }

    func fetchRecentSnippets(limit: Int) async throws -> [RecentWorkoutSnippetDTO] {
        // TODO: NSFetchRequest<RecentWorkoutSnippet> sorted by decayScore desc, limited
        return []
    }

    func markRecentUsed(id: UUID) async throws {
        // TODO: fetch by id, increment useCount, set lastUsedAt, recalculate decayScore, save
    }

    func clearRecents() async throws {
        // TODO: NSBatchDeleteRequest for all RecentWorkoutSnippet entities
    }

    func pruneOldRecents() async throws {
        // TODO: Delete snippets where decayScore < threshold or createdAt > X days
    }
}
