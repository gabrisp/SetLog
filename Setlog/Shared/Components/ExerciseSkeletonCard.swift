import SwiftUI

struct ExerciseSkeletonCard: View {

    let exerciseName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exerciseName)
                .font(.subheadline.weight(.semibold))

            // TODO: Replace with real set rows from WorkoutSetDTO list
            Text("No sets yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
