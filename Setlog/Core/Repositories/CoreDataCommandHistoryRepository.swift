import CoreData

final class CoreDataCommandHistoryRepository: CommandHistoryRepositoryProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func save(item: CommandHistoryItemDTO) async throws {
        try await context.perform {
            let entity = CommandHistoryItem(context: self.context)
            entity.id = item.id
            entity.rawText = item.rawText
            entity.parsedCommandType = item.parsedCommandType
            entity.dayKey = item.dayKey
            entity.workoutSessionID = item.workoutSessionID
            entity.createdAt = item.createdAt
            entity.success = item.success
            try self.context.save()
        }
    }

    func fetchRecent(limit: Int) async throws -> [CommandHistoryItemDTO] {
        try await context.perform {
            let request = CommandHistoryItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            request.fetchLimit = limit

            return try self.context.fetch(request).map { item in
                CommandHistoryItemDTO(
                    id: item.id ?? UUID(),
                    rawText: item.rawText ?? "",
                    parsedCommandType: item.parsedCommandType,
                    dayKey: item.dayKey ?? "",
                    workoutSessionID: item.workoutSessionID,
                    createdAt: item.createdAt ?? Date(),
                    success: item.success
                )
            }
        }
    }
}
