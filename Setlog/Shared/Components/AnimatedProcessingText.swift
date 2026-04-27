import SwiftUI

struct AnimatedProcessingText: View {

    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .overlay {
                if !reduceMotion {
                    shimmerOverlay
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                phase = -1
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
            .onChange(of: reduceMotion) { _, newValue in
                if newValue {
                    phase = -1
                } else {
                    phase = -1
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        phase = 1.2
                    }
                }
            }
    }

    private var shimmerOverlay: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.blue.opacity(0.85),
                    Color.white.opacity(0.15)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: max(44, width * 0.8))
            .offset(x: phase * width)
            .mask(
                Text(text)
                    .font(.footnote.weight(.medium))
            )
        }
        .allowsHitTesting(false)
    }
}
