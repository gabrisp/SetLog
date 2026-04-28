import SwiftUI
import UIKit

struct UIKitCornerTopBar: UIViewRepresentable {

    struct ButtonSpec {
        let systemImageName: String
        let accessibilityLabel: String
        let action: () -> Void
    }

    let leading: ButtonSpec?
    let trailing: ButtonSpec?

    func makeUIView(context: Context) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        toolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
        toolbar.backgroundColor = .clear
        toolbar.isTranslucent = true
        configure(toolbar, coordinator: context.coordinator)
        return toolbar
    }

    func updateUIView(_ uiView: UIToolbar, context: Context) {
        configure(uiView, coordinator: context.coordinator)
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
        Coordinator(leading: leading?.action, trailing: trailing?.action)
    }

    private func configure(_ toolbar: UIToolbar, coordinator: Coordinator) {
        coordinator.leadingAction = leading?.action
        coordinator.trailingAction = trailing?.action

        var items: [UIBarButtonItem] = []

        if let leading {
            let item = UIBarButtonItem(
                image: UIImage(systemName: leading.systemImageName),
                style: .plain,
                target: coordinator,
                action: #selector(Coordinator.didTapLeading)
            )
            item.accessibilityLabel = leading.accessibilityLabel
            items.append(item)
        }

        items.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))

        if let trailing {
            let item = UIBarButtonItem(
                image: UIImage(systemName: trailing.systemImageName),
                style: .plain,
                target: coordinator,
                action: #selector(Coordinator.didTapTrailing)
            )
            item.accessibilityLabel = trailing.accessibilityLabel
            items.append(item)
        }

        toolbar.items = items
    }

    final class Coordinator: NSObject {
        var leadingAction: (() -> Void)?
        var trailingAction: (() -> Void)?

        init(leading: (() -> Void)?, trailing: (() -> Void)?) {
            self.leadingAction = leading
            self.trailingAction = trailing
        }

        @objc func didTapLeading() { leadingAction?() }
        @objc func didTapTrailing() { trailingAction?() }
    }
}
