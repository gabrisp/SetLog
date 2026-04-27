import Foundation

@Observable
final class SettingsViewModel {

    private let userPreferencesService: UserPreferencesServiceProtocol
    private let entitlementService: EntitlementServiceProtocol

    var isPro: Bool { entitlementService.isPro }

    init(
        userPreferencesService: UserPreferencesServiceProtocol,
        entitlementService: EntitlementServiceProtocol
    ) {
        self.userPreferencesService = userPreferencesService
        self.entitlementService = entitlementService
    }

    func resetOnboarding() {
        userPreferencesService.resetOnboarding()
    }

    func clearRecentItems() {
        // TODO: recentItemsRepository.clearRecents()
    }
}
