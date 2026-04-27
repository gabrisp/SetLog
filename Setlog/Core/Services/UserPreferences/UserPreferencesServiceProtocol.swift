import Foundation

protocol UserPreferencesServiceProtocol {
    var hasCompletedOnboarding: Bool { get }
    func markOnboardingCompleted()
    func resetOnboarding()
}
