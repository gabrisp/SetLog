import SwiftUI

struct ProcessingBubble: View {

    let message: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerPhase: CGFloat = 0

    private let gradientColors: [Color] = [
        Color.white.opacity(0.6),
        Color.accentColor,
        Color(red: 0.6, green: 0.4, blue: 1.0),
        Color.white.opacity(0.6),
    ]

    var body: some View {
        messageText
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .setlogGlass(in: Capsule())
            .transition(.asymmetric(
                insertion: .scale(scale: 0.82, anchor: .bottom).combined(with: .opacity),
                removal: .scale(scale: 0.82, anchor: .bottom).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: message)
    }

    private var messageText: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .overlay {
                if !reduceMotion {
                    shimmerLayer
                }
            }
            .id(message)
            .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            .onAppear { startShimmer() }
            .onChange(of: reduceMotion) { _, reduced in
                if reduced { shimmerPhase = 0 } else { startShimmer() }
            }
    }

    private var shimmerLayer: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                .frame(width: w * 1.6)
                .offset(x: shimmerPhase * (w + w * 0.6) - w * 0.8)
                .mask(
                    Text(message)
                        .font(.subheadline.weight(.medium))
                )
        }
        .allowsHitTesting(false)
    }

    private func startShimmer() {
        shimmerPhase = 0
        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
            shimmerPhase = 1
        }
    }
}
