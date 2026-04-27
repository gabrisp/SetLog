import Foundation

struct SavedExerciseDTO {
    var id: UUID
    var name: String
    var normalizedName: String
    var imageFileName: String?
    var primaryMusclesText: String?
    var secondaryMusclesText: String?
    var equipment: String?
    var descriptionText: String?
    var instructionsText: String?
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?
    var useCount: Int32
    var isArchived: Bool
}

struct FavoriteWorkoutSnippetDTO {
    var id: UUID
    var savedExerciseID: UUID
    var title: String
    var payloadJSON: String
    var snippetType: String
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?
    var useCount: Int32
}

protocol ExerciseRepositoryProtocol {
    func fetchSavedExercises() async throws -> [SavedExerciseDTO]
    func fetchSavedExercise(id: UUID) async throws -> SavedExerciseDTO?
    func createSavedExercise(name: String, equipment: String?) async throws -> SavedExerciseDTO
    func updateSavedExercise(id: UUID, name: String?, equipment: String?) async throws
    func archiveSavedExercise(id: UUID) async throws
    func markUsed(id: UUID) async throws
    func createFavoriteSnippet(savedExerciseID: UUID, title: String, payloadJSON: String, snippetType: String) async throws -> FavoriteWorkoutSnippetDTO
    func fetchFavoriteSnippets() async throws -> [FavoriteWorkoutSnippetDTO]
}
