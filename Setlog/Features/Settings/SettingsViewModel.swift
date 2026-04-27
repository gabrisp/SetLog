import Foundation

@MainActor
@Observable
final class SettingsViewModel {

    private let userPreferencesService: UserPreferencesServiceProtocol
    private let entitlementService: EntitlementServiceProtocol

    var isPro: Bool { entitlementService.isPro }
    var fmDebugStatus: FoundationModelsDebugStatus = .probe()
    var fmDiagnostics: FoundationModelsDiagnosticsSnapshot = .init()

    init(
        userPreferencesService: UserPreferencesServiceProtocol,
        entitlementService: EntitlementServiceProtocol
    ) {
        self.userPreferencesService = userPreferencesService
        self.entitlementService = entitlementService
        refreshAIFeaturesDebug()
    }

    func resetOnboarding() {
        userPreferencesService.resetOnboarding()
    }

    func clearRecentItems() {
        // TODO: recentItemsRepository.clearRecents()
    }

    func refreshAIFeaturesDebug() {
        fmDebugStatus = .probe()
        Task {
            let snapshot = await FoundationModelsRuntimeDiagnostics.shared.current()
            await MainActor.run {
                self.fmDiagnostics = snapshot
            }
        }
    }
}
