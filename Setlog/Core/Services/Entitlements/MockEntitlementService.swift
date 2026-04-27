import Foundation

final class MockEntitlementService: EntitlementServiceProtocol {

    private static let freeFeatures: Set<ProFeature> = []

    var isPro: Bool { false }

    func canUse(_ feature: ProFeature) -> Bool {
        Self.freeFeatures.contains(feature)
    }
}
