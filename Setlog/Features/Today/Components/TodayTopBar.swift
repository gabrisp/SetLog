import SwiftUI
import UIKit

struct TodayTopBar: UIViewRepresentable {

    let onCalendarTap: () -> Void
    let onSavedExercisesTap: () -> Void

    func makeUIView(context: Context) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        toolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
        toolbar.backgroundColor = .clear
        toolbar.isTranslucent = true

        let calendarItem = UIBarButtonItem(
            image: UIImage(systemName: "calendar"),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.didTapCalendar)
        )

        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let savedItem = UIBarButtonItem(
            image: UIImage(systemName: "dumbbell"),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.didTapSavedExercises)
        )

        toolbar.items = [calendarItem, spacer, savedItem]
        return toolbar
    }

    func updateUIView(_ uiView: UIToolbar, context: Context) {
        context.coordinator.onCalendarTap = onCalendarTap
        context.coordinator.onSavedExercisesTap = onSavedExercisesTap
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIToolbar, context: Context) -> CGSize? {
        let resolvedWidth: CGFloat
        if let width = proposal.width, width > 0 {
            resolvedWidth = width
        } else if uiView.bounds.width > 0 {
            resolvedWidth = uiView.bounds.width
        } else if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            resolvedWidth = scene.screen.bounds.width
        } else {
            resolvedWidth = 390
        }
        return CGSize(width: resolvedWidth, height: 44)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCalendarTap: onCalendarTap, onSavedExercisesTap: onSavedExercisesTap)
    }

    final class Coordinator: NSObject {
        var onCalendarTap: () -> Void
        var onSavedExercisesTap: () -> Void

        init(onCalendarTap: @escaping () -> Void, onSavedExercisesTap: @escaping () -> Void) {
            self.onCalendarTap = onCalendarTap
            self.onSavedExercisesTap = onSavedExercisesTap
        }

        @objc func didTapCalendar() { onCalendarTap() }
        @objc func didTapSavedExercises() { onSavedExercisesTap() }
    }
}
