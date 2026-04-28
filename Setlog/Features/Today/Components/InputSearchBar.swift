import SwiftUI
import UIKit

struct InputSearchBar: UIViewRepresentable {

    let onCalendarTap: () -> Void
    let onSavedExercisesTap: () -> Void

    func makeUIView(context: Context) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        toolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
        toolbar.backgroundColor = .clear
        toolbar.isTranslucent = true

        let calendarItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.didTapCalendar)
        )

        let spacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        spacer.width = 3

        let container = InputSearchContainer()
        container.onHeightChanged = { [weak toolbar] _ in
            toolbar?.invalidateIntrinsicContentSize()
            toolbar?.setNeedsLayout()
        }
        context.coordinator.container = container

        let searchItem = UIBarButtonItem(customView: container)
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        toolbar.items = [calendarItem, spacer, flexibleSpace, searchItem]
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
        context.coordinator.container?.updateWidth(toolbarWidth: resolvedWidth)
        let contentHeight = context.coordinator.container?.currentHeight ?? 44
        return CGSize(width: resolvedWidth, height: contentHeight)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCalendarTap: onCalendarTap, onSavedExercisesTap: onSavedExercisesTap)
    }

    final class Coordinator: NSObject {
        var onCalendarTap: () -> Void
        var onSavedExercisesTap: () -> Void
        weak var container: InputSearchContainer?

        init(onCalendarTap: @escaping () -> Void, onSavedExercisesTap: @escaping () -> Void) {
            self.onCalendarTap = onCalendarTap
            self.onSavedExercisesTap = onSavedExercisesTap
        }

        @objc func didTapCalendar() { onCalendarTap() }
        @objc func didTapSavedExercises() { onSavedExercisesTap() }
    }
}

// MARK: - Container view

final class InputSearchContainer: UIView, UITextViewDelegate {

    var onHeightChanged: ((CGFloat) -> Void)?

    private let field = UITextView()
    private let placeholder = UILabel()
    private let sendButton = UIButton(type: .system)

    private let buttonSize: CGFloat = 30
    private let minHeight: CGFloat = 44
    private let maxHeight: CGFloat = 120
    private let verticalPadding: CGFloat = 7  // padding above and below text within bar

    private(set) var currentHeight: CGFloat = 44

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        field.font = .systemFont(ofSize: 17)
        field.textColor = .label
        field.tintColor = .label
        field.backgroundColor = .clear
        field.returnKeyType = .send
        field.autocorrectionType = .yes
        field.autocapitalizationType = .sentences
        field.isScrollEnabled = false
        field.textContainerInset = .zero
        field.textContainer.lineFragmentPadding = 0
        field.delegate = self

        placeholder.text = "Escribe un comando..."
        placeholder.font = .systemFont(ofSize: 17)
        placeholder.textColor = .placeholderText

        sendButton.setImage(
            UIImage(
                systemName: "arrow.up.circle.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: buttonSize, weight: .regular)
            ),
            for: .normal
        )
        sendButton.tintColor = UIColor(named: "AccentColor") ?? .systemBlue

        addSubview(field)
        addSubview(placeholder)
        addSubview(sendButton)
    }

    // MARK: - Layout

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: currentHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        let fieldW = w - buttonSize - 8

        // Text sits in the center vertically with padding on top/bottom
        let textH = h - verticalPadding * 2
        let textY = verticalPadding

        field.frame = CGRect(x: 0, y: textY, width: fieldW, height: textH)
        placeholder.sizeToFit()
        placeholder.frame.origin = CGPoint(x: 0, y: (h - placeholder.bounds.height) / 2)
        sendButton.frame = CGRect(x: w - buttonSize, y: (h - buttonSize) / 2, width: buttonSize, height: buttonSize)
    }

    // MARK: - Height calculation

    private func recalculateHeight() {
        let fieldW = bounds.width - buttonSize - 8
        guard fieldW > 0 else { return }
        let fitSize = field.sizeThatFits(CGSize(width: fieldW, height: .infinity))
        let textH = fitSize.height
        let needed = min(max(textH + verticalPadding * 2, minHeight), maxHeight)
        field.isScrollEnabled = (textH + verticalPadding * 2) > maxHeight
        guard abs(needed - currentHeight) > 0.5 else { return }
        currentHeight = needed
        invalidateIntrinsicContentSize()
        onHeightChanged?(needed)
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        placeholder.isHidden = !textView.text.isEmpty
        recalculateHeight()
    }

    // MARK: - Width

    private var explicitWidthConstraint: NSLayoutConstraint?

    func updateWidth(toolbarWidth: CGFloat) {
        let reserved: CGFloat = 44 + 3 + 16
        let target = max(0, toolbarWidth - reserved)
        if let c = explicitWidthConstraint {
            c.constant = target
        } else {
            let c = widthAnchor.constraint(equalToConstant: target)
            c.priority = .defaultHigh
            c.isActive = true
            explicitWidthConstraint = c
        }
    }
}
