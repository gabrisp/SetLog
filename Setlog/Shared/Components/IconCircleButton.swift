import SwiftUI

struct IconCircleButton: View {

    let systemImage: String
    let action: () -> Void
    var size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .frame(width: size, height: size)
                // TODO: apply .setlogGlass(in: Circle()) when visual design is finalized
        }
        .buttonStyle(.plain)
    }
}
