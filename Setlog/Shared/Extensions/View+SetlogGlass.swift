import SwiftUI

extension View {
    /// Applies Liquid Glass on iOS 26+; falls back to ultraThinMaterial on iOS 17–25.
    /// Pass the shape that matches each component's design intent.
    @ViewBuilder
    func setlogGlass(
        in shape: some Shape = Capsule()
    ) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
