import SwiftUI

struct SetRowSkeleton: View {

    let setNumber: Int

    var body: some View {
        HStack {
            Text("Set \(setNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(width: 80, height: 14)

            Spacer()

            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(width: 60, height: 14)
        }
    }
}
