import SwiftUI

struct RootView: View {

    @State private var viewModel: RootViewModel

    init(userPreferencesService: UserPreferencesServiceProtocol) {
        _viewModel = State(wrappedValue: RootViewModel(userPreferencesService: userPreferencesService))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack {
            switch viewModel.rootState {
            case .splash:
                SplashView(onFinished: viewModel.onSplashFinished)
                    .transition(.opacity)

            case .onboarding:
                OnboardingFlowView(onCompleted: viewModel.onOnboardingCompleted)
                    .transition(.opacity)

            case .app:
                MainAppFlowView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.rootState)
        .onAppear {
            print("[ROOT] appear state=\(viewModel.rootState.debugName)")
        }
        .onChange(of: viewModel.rootState) { _, newValue in
            print("[ROOT] state changed -> \(newValue.debugName)")
        }
    }
}
