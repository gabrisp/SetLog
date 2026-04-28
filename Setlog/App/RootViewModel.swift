import Foundation

enum RootAppState {
    case splash
    case onboarding
    case app
}

extension RootAppState {
    var debugName: String {
        switch self {
        case .splash: return "splash"
        case .onboarding: return "onboarding"
        case .app: return "app"
        }
    }
}

@Observable
final class RootViewModel {

    var rootState: RootAppState = .splash

    private let userPreferencesService: UserPreferencesServiceProtocol

    init(userPreferencesService: UserPreferencesServiceProtocol) {
        self.userPreferencesService = userPreferencesService
        print("[ROOT_VM] init hasCompletedOnboarding=\(userPreferencesService.hasCompletedOnboarding)")
    }

    func onSplashFinished() {
        print("[ROOT_VM] onSplashFinished called")
        if userPreferencesService.hasCompletedOnboarding {
            rootState = .app
        } else {
            rootState = .onboarding
        }
        print("[ROOT_VM] nextState=\(rootState.debugName)")
    }

    func onOnboardingCompleted() {
        print("[ROOT_VM] onOnboardingCompleted called")
        userPreferencesService.markOnboardingCompleted()
        rootState = .app
        print("[ROOT_VM] nextState=\(rootState.debugName)")
    }
}
