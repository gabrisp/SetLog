import CoreData

final class CoreDataCommandHistoryRepository: CommandHistoryRepositoryProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func save(item: CommandHistoryItemDTO) async throws {
        // TODO: Create CommandHistoryItem entity, map fields, save context
    }

    func fetchRecent(limit: Int) async throws -> [CommandHistoryItemDTO] {
        // TODO: NSFetchRequest<CommandHistoryItem> sorted by createdAt desc, limited
        return []
    }
}
