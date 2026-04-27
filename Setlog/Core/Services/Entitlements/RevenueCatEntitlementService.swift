import Foundation
import RevenueCat

final class RevenueCatEntitlementService: EntitlementServiceProtocol {

    private static let proEntitlementIdentifier = "pro"

    // TODO: Call Purchases.configure(withAPIKey:) in SetlogApp or AppEnvironment
    // TODO: Subscribe to Purchases.shared.customerInfoStream for live updates

    var isPro: Bool {
        // TODO: Return true when CustomerInfo contains the "pro" entitlement
        return false
    }

    func canUse(_ feature: ProFeature) -> Bool {
        // TODO: Map ProFeature to entitlement identifiers or product levels
        return isPro
    }
}
