import SwiftUI

// TODO: Bind to WorkoutSetDTO when repository layer is wired
struct ExerciseSetRow: View {

    let setNumber: Int
    let reps: Int
    let weight: Double
    let unit: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text("Set \(setNumber)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)

                Text("\(reps) reps")
                    .font(.subheadline)

                Spacer()

                Text("\(weight, specifier: "%.1f") \(unit)")
                    .font(.subheadline.weight(.medium))
            }
        }
        .buttonStyle(.plain)
    }
}
