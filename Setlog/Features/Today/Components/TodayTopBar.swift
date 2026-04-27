import SwiftUI

// TODO: Replace internals with UIKit UIViewController-based toolbar when visual design is finalized.
// External API (callbacks) must remain stable — TodayView only sees closures, never UIKit internals.
struct TodayTopBar: View {

    let onCalendarTap: () -> Void
    let onSavedExercisesTap: () -> Void

    var body: some View {
        HStack {
            Button(action: onCalendarTap) {
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .medium))
            }

            Spacer()

            Button(action: onSavedExercisesTap) {
                Image(systemName: "dumbbell")
                    .font(.system(size: 17, weight: .medium))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        // TODO: apply setlogGlass(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}
