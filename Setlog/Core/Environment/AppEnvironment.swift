import SwiftUI
import CoreData

@Observable
final class AppEnvironment {

    let persistenceController: PersistenceController
    let userPreferencesService: UserPreferencesServiceProtocol
    let entitlementService: EntitlementServiceProtocol
    let router: AppRouter
    let workoutRepository: WorkoutRepositoryProtocol
    let exerciseRepository: ExerciseRepositoryProtocol
    let recentItemsRepository: RecentItemsRepositoryProtocol
    let commandHistoryRepository: CommandHistoryRepositoryProtocol
    let commandInterpreter: WorkoutCommandInterpreter

    init(
        persistenceController: PersistenceController = .shared,
        userPreferencesService: UserPreferencesServiceProtocol = UserDefaultsUserPreferencesService(),
        entitlementService: EntitlementServiceProtocol = MockEntitlementService()
    ) {
        self.persistenceController = persistenceController
        self.userPreferencesService = userPreferencesService
        self.entitlementService = entitlementService
        self.router = AppRouter()

        let viewContext = persistenceController.container.viewContext
        self.workoutRepository = CoreDataWorkoutRepository(context: viewContext)
        self.exerciseRepository = CoreDataExerciseRepository(context: viewContext)
        self.recentItemsRepository = CoreDataRecentItemsRepository(context: viewContext)
        self.commandHistoryRepository = CoreDataCommandHistoryRepository(context: viewContext)

        let resolutionRepo = CoreDataUserResolutionRepository(context: viewContext)
        let resolutionCache = CommandResolutionCache(repository: resolutionRepo)
        self.commandInterpreter = WorkoutCommandInterpreter(
            entitlementService: entitlementService,
            resolutionCache: resolutionCache
        )
    }
}

// MARK: - SwiftUI environment key

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = AppEnvironment()
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
