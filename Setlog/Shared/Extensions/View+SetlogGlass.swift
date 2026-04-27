import SwiftUI

extension View {
    /// Applies Liquid Glass on iOS 26+, falls back to ultraThinMaterial on older OS.
    /// Pass the glass style and shape that match each component's design intent.
    @ViewBuilder
    func setlogGlass(
        in shape: some Shape = Capsule(),
        isEnabled: Bool = true
    ) -> some View {
        if #available(iOS 26, *) {
            // .regular is the default Glass; callers can override via a separate modifier
            // when they need .interactive or other variants.
            self.glassEffect(.regular, in: shape, isEnabled: isEnabled)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
