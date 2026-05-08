import SwiftUI
import UIKit

struct TodayTopBar: UIViewRepresentable {

    let dayKey: String
    let dayDisplayFormat: String
    let isEditingMode: Bool
    let onCalendarTap: () -> Void
    let onDayTap: () -> Void
    let onEnterEditTap: () -> Void
    let onCancelEditTap: () -> Void
    let onConfirmEditTap: () -> Void

    func makeUIView(context: Context) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        toolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
        toolbar.backgroundColor = .clear
        toolbar.isTranslucent = true

        let trailingSystemName = isEditingMode ? "checkmark" : "pencil"
        let trailingItem = UIBarButtonItem(
            image: UIImage(systemName: trailingSystemName),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.didTapTrailing)
        )

        if isEditingMode {
            let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            toolbar.items = [spacer, trailingItem]
            context.coordinator.dayButton = nil
        } else {
            let leadingItem = UIBarButtonItem(
                image: UIImage(systemName: "calendar"),
                style: .plain,
                target: context.coordinator,
                action: #selector(Coordinator.didTapLeading)
            )

            let dayButton = UIButton(type: .system)
            dayButton.addTarget(context.coordinator, action: #selector(Coordinator.didTapDay), for: .touchUpInside)
            dayButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
            let dayItem = UIBarButtonItem(customView: dayButton)
            let spacerLeft = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let spacerRight = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

            toolbar.items = [leadingItem, spacerLeft, dayItem, spacerRight, trailingItem]
            context.coordinator.dayButton = dayButton
            updateDayButton(dayButton)
        }
        return toolbar
    }

    func updateUIView(_ uiView: UIToolbar, context: Context) {
        context.coordinator.isEditingMode = isEditingMode
        context.coordinator.onCalendarTap = onCalendarTap
        context.coordinator.onDayTap = onDayTap
        context.coordinator.onEnterEditTap = onEnterEditTap
        context.coordinator.onCancelEditTap = onCancelEditTap
        context.coordinator.onConfirmEditTap = onConfirmEditTap

        let currentCount = uiView.items?.count ?? 0
        let expectedCount = isEditingMode ? 2 : 5
        if currentCount != expectedCount {
            if isEditingMode {
                let trailingItem = UIBarButtonItem(
                    image: UIImage(systemName: "checkmark"),
                    style: .plain,
                    target: context.coordinator,
                    action: #selector(Coordinator.didTapTrailing)
                )
                let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
                uiView.items = [spacer, trailingItem]
                context.coordinator.dayButton = nil
            } else {
                let leadingItem = UIBarButtonItem(
                    image: UIImage(systemName: "calendar"),
                    style: .plain,
                    target: context.coordinator,
                    action: #selector(Coordinator.didTapLeading)
                )
                let dayButton = UIButton(type: .system)
                dayButton.addTarget(context.coordinator, action: #selector(Coordinator.didTapDay), for: .touchUpInside)
                dayButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
                let dayItem = UIBarButtonItem(customView: dayButton)
                let spacerLeft = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
                let spacerRight = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
                let trailingItem = UIBarButtonItem(
                    image: UIImage(systemName: "pencil"),
                    style: .plain,
                    target: context.coordinator,
                    action: #selector(Coordinator.didTapTrailing)
                )
                uiView.items = [leadingItem, spacerLeft, dayItem, spacerRight, trailingItem]
                context.coordinator.dayButton = dayButton
                updateDayButton(dayButton)
            }
        } else {
            uiView.items?.last?.image = UIImage(systemName: isEditingMode ? "checkmark" : "pencil")
            if !isEditingMode, let dayButton = context.coordinator.dayButton {
                updateDayButton(dayButton)
            }
        }
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
        Coordinator(
            isEditingMode: isEditingMode,
            onCalendarTap: onCalendarTap,
            onDayTap: onDayTap,
            onEnterEditTap: onEnterEditTap,
            onCancelEditTap: onCancelEditTap,
            onConfirmEditTap: onConfirmEditTap
        )
    }

    private func updateDayButton(_ button: UIButton) {
        let title = formattedDay()
        button.setTitle(title, for: .normal)
        button.sizeToFit()
    }

    private func formattedDay() -> String {
        guard let date = Date.date(fromDayKey: dayKey) else { return dayKey }
        let formatter = DateFormatter()
        formatter.dateFormat = dayDisplayFormat
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    final class Coordinator: NSObject {
        var isEditingMode: Bool
        var onCalendarTap: () -> Void
        var onDayTap: () -> Void
        var onEnterEditTap: () -> Void
        var onCancelEditTap: () -> Void
        var onConfirmEditTap: () -> Void
        weak var dayButton: UIButton?

        init(
            isEditingMode: Bool,
            onCalendarTap: @escaping () -> Void,
            onDayTap: @escaping () -> Void,
            onEnterEditTap: @escaping () -> Void,
            onCancelEditTap: @escaping () -> Void,
            onConfirmEditTap: @escaping () -> Void
        ) {
            self.isEditingMode = isEditingMode
            self.onCalendarTap = onCalendarTap
            self.onDayTap = onDayTap
            self.onEnterEditTap = onEnterEditTap
            self.onCancelEditTap = onCancelEditTap
            self.onConfirmEditTap = onConfirmEditTap
        }

        @objc func didTapLeading() {
            onCalendarTap()
        }

        @objc func didTapDay() { onDayTap() }

        @objc func didTapTrailing() {
            if isEditingMode {
                onConfirmEditTap()
            } else {
                onEnterEditTap()
            }
        }
    }
}
