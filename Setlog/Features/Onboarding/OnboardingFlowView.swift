import SwiftUI

struct OnboardingFlowView: View {

    let onCompleted: () -> Void

    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        // TODO: Replace with real onboarding UI / page flow
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                if let page = viewModel.pages[safe: viewModel.currentIndex] {
                    Text(page.title)
                        .font(.title.weight(.semibold))

                    Text(page.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button(viewModel.isLastPage ? "Get Started" : "Continue") {
                    viewModel.advance()
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            viewModel.onCompleted = onCompleted
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
