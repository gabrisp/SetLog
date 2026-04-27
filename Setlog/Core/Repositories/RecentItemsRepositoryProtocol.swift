import Foundation

struct RecentWorkoutSnippetDTO {
    var id: UUID
    var title: String
    var normalizedTitle: String
    var payloadJSON: String
    var snippetType: String
    var createdAt: Date
    var lastUsedAt: Date?
    var useCount: Int32
    var decayScore: Double
    var sourceDayKey: String?
    var sourceWorkoutSessionID: UUID?
    var sourceExerciseEntryID: UUID?
}

protocol RecentItemsRepositoryProtocol {
    func saveRecentSnippet(title: String, payloadJSON: String, snippetType: String, sourceDayKey: String?) async throws
    func fetchRecentSnippets(limit: Int) async throws -> [RecentWorkoutSnippetDTO]
    func markRecentUsed(id: UUID) async throws
    func clearRecents() async throws
    func pruneOldRecents() async throws
}
