import SwiftUI

struct MinimalSectionHeader: View {

    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }
}
