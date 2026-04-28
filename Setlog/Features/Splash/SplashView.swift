import SwiftUI

struct SplashView: View {

    let onFinished: () -> Void

    @State private var viewModel = SplashViewModel()

    var body: some View {
        // TODO: Replace with custom splash animation / branding
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            Text("Setlog")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .onAppear {
            print("[SPLASH] appear")
            viewModel.onFinished = onFinished
            viewModel.start()
        }
        .onDisappear {
            print("[SPLASH] disappear")
        }
    }
}
