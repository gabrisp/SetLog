import Foundation

final class UserDefaultsUserPreferencesService: UserPreferencesServiceProtocol {

    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }

    func markOnboardingCompleted() {
        defaults.set(true, forKey: Keys.hasCompletedOnboarding)
    }

    func resetOnboarding() {
        defaults.removeObject(forKey: Keys.hasCompletedOnboarding)
    }
}
