import Foundation

enum RootAppState {
    case splash
    case onboarding
    case app
}

@Observable
final class RootViewModel {

    var rootState: RootAppState = .splash

    private let userPreferencesService: UserPreferencesServiceProtocol

    init(userPreferencesService: UserPreferencesServiceProtocol) {
        self.userPreferencesService = userPreferencesService
    }

    func onSplashFinished() {
        if userPreferencesService.hasCompletedOnboarding {
            rootState = .app
        } else {
            rootState = .onboarding
        }
    }

    func onOnboardingCompleted() {
        userPreferencesService.markOnboardingCompleted()
        rootState = .app
    }
}
