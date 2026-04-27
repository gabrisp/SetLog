import SwiftUI

// TODO: Bind to WorkoutSessionDTO when repository layer is wired
struct WorkoutSessionCard: View {

    let title: String
    let type: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(type.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
