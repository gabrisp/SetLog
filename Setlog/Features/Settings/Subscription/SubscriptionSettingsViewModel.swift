import Foundation

@Observable
final class SubscriptionSettingsViewModel {

    private let entitlementService: EntitlementServiceProtocol

    var isPro: Bool { entitlementService.isPro }
    let proFeatures: [ProFeature] = ProFeature.allCases

    init(entitlementService: EntitlementServiceProtocol) {
        self.entitlementService = entitlementService
    }

    func upgrade() {
        // TODO: Trigger RevenueCat purchase flow
    }

    func restorePurchases() {
        // TODO: Purchases.shared.restorePurchases(...)
    }
}
