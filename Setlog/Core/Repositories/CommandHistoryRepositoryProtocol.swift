import Foundation

struct CommandHistoryItemDTO {
    var id: UUID
    var rawText: String
    var parsedCommandType: String?
    var dayKey: String
    var workoutSessionID: UUID?
    var createdAt: Date
    var success: Bool
}

protocol CommandHistoryRepositoryProtocol {
    func save(item: CommandHistoryItemDTO) async throws
    func fetchRecent(limit: Int) async throws -> [CommandHistoryItemDTO]
}
