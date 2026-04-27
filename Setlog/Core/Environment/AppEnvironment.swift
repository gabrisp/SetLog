import SwiftUI

@Observable
final class AppEnvironment {

    let userPreferencesService: UserPreferencesServiceProtocol
    let entitlementService: EntitlementServiceProtocol
    let router: AppRouter

    // TODO: let workoutRepository: WorkoutRepositoryProtocol
    // TODO: let exerciseRepository: ExerciseRepositoryProtocol
    // TODO: let recentItemsRepository: RecentItemsRepositoryProtocol
    // TODO: let commandHistoryRepository: CommandHistoryRepositoryProtocol
    // TODO: let commandInterpreter: WorkoutCommandInterpreter
    // TODO: let dateProvider: DateProviding
    // TODO: let hapticsService: HapticsServiceProtocol

    init(
        userPreferencesService: UserPreferencesServiceProtocol = UserDefaultsUserPreferencesService(),
        entitlementService: EntitlementServiceProtocol = MockEntitlementService()
    ) {
        self.userPreferencesService = userPreferencesService
        self.entitlementService = entitlementService
        self.router = AppRouter()
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
