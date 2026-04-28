import Foundation

struct UserCommandResolutionDTO {
    var id: UUID
    var rawInput: String           // normalized (lowercase, no diacritics)
    var resolvedExerciseName: String
    var resolvedIntent: String
    var useCount: Int
    var lastUsedAt: Date
    var createdAt: Date
}

protocol UserResolutionRepositoryProtocol {
    func save(rawInput: String, resolvedExerciseName: String, resolvedIntent: String) async throws
    func findAll() async throws -> [UserCommandResolutionDTO]
    func incrementUseCount(id: UUID) async throws
    func delete(id: UUID) async throws
}
