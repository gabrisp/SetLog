import Foundation

protocol EntitlementServiceProtocol {
    var isPro: Bool { get }
    func canUse(_ feature: ProFeature) -> Bool
}
