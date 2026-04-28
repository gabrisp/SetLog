import SwiftUI
import UIKit

struct CalendarTopBar: UIViewRepresentable {

    let onSettingsTap: () -> Void

    func makeUIView(context: Context) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        toolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
        toolbar.backgroundColor = .clear
        toolbar.isTranslucent = true

        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let settingsItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.didTapSettings)
        )

        toolbar.items = [spacer, settingsItem]
        return toolbar
    }

    func updateUIView(_ uiView: UIToolbar, context: Context) {
        context.coordinator.onSettingsTap = onSettingsTap
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
        Coordinator(onSettingsTap: onSettingsTap)
    }

    final class Coordinator: NSObject {
        var onSettingsTap: () -> Void

        init(onSettingsTap: @escaping () -> Void) {
            self.onSettingsTap = onSettingsTap
        }

        @objc func didTapSettings() { onSettingsTap() }
    }
}
