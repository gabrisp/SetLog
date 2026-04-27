import CoreData

final class CoreDataExerciseRepository: ExerciseRepositoryProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchSavedExercises() async throws -> [SavedExerciseDTO] {
        // TODO: NSFetchRequest<SavedExercise> excluding isArchived = true
        return []
    }

    func fetchSavedExercise(id: UUID) async throws -> SavedExerciseDTO? {
        // TODO: fetch by id
        return nil
    }

    func createSavedExercise(name: String, equipment: String?) async throws -> SavedExerciseDTO {
        fatalError("TODO: implement createSavedExercise")
    }

    func updateSavedExercise(id: UUID, name: String?, equipment: String?) async throws {
        // TODO: fetch by id, apply updates, save
    }

    func archiveSavedExercise(id: UUID) async throws {
        // TODO: fetch by id, set isArchived = true, save
    }

    func markUsed(id: UUID) async throws {
        // TODO: fetch by id, increment useCount, set lastUsedAt, save
    }

    func createFavoriteSnippet(savedExerciseID: UUID, title: String, payloadJSON: String, snippetType: String) async throws -> FavoriteWorkoutSnippetDTO {
        fatalError("TODO: implement createFavoriteSnippet")
    }

    func fetchFavoriteSnippets() async throws -> [FavoriteWorkoutSnippetDTO] {
        // TODO: NSFetchRequest<FavoriteWorkoutSnippet> sorted by lastUsedAt desc
        return []
    }
}
