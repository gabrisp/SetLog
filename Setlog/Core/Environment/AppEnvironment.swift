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
    let userResolutionRepository: UserResolutionRepositoryProtocol
    let commandResolutionCache: CommandResolutionCache
    let exerciseIdentityResolver: ExerciseIdentityResolver
    let exerciseIdentityBackfillService: ExerciseIdentityBackfillService
    let statsRepository: StatsRepositoryProtocol

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
        self.userResolutionRepository = CoreDataUserResolutionRepository(context: viewContext)
        self.commandResolutionCache = CommandResolutionCache(repository: userResolutionRepository)
        self.exerciseIdentityResolver = ExerciseIdentityResolver(
            exerciseRepository: exerciseRepository,
            resolutionCache: commandResolutionCache
        )
        self.exerciseIdentityBackfillService = ExerciseIdentityBackfillService(
            context: viewContext,
            resolver: exerciseIdentityResolver
        )
        self.statsRepository = CoreDataStatsRepository(context: viewContext)

        AIUsageService.shared.configure(
            entitlementService: entitlementService,
            currentUserProvider: LocalCurrentUserProvider(),
            repository: UserDefaultsAIUsageRepository()
        )

        let environmentAPIKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"]
        if let environmentAPIKey, !environmentAPIKey.isEmpty {
            // Secure bootstrap for local debug: inject from scheme env into app keychain.
            GroqKeychainStore.storeKey(environmentAPIKey)
        }

        let forceMock = ProcessInfo.processInfo.environment["AI_FORCE_MOCK"] == "1"
        AICommandService.shared.configure(forceMockProvider: forceMock, groqAPIKey: environmentAPIKey)

        Task { @MainActor in
            await commandResolutionCache.load()
            await exerciseIdentityBackfillService.runIfNeeded()
        }
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
