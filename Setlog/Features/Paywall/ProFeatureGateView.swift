import SwiftUI

struct ProFeatureGateView: View {

    let feature: ProFeature
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "star.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text(feature.displayName)
                    .font(.title3.weight(.semibold))

                Text("This feature requires a Pro subscription.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button("Upgrade to Pro") {
                router.dismissSheet()
                router.go(.settings(.subscription))
            }
            .buttonStyle(.borderedProminent)

            Button("Not Now") {
                router.dismissSheet()
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
        .presentationDetents([.fraction(0.35), .medium])
        .presentationDragIndicator(.visible)
    }
}
