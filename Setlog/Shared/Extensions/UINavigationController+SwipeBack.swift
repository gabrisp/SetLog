import SwiftUI
import UIKit

private struct InteractivePopGestureConfigurator: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.coordinator = context.coordinator
        uiViewController.configureInteractivePopGesture()
    }

    final class Controller: UIViewController {
        weak var coordinator: Coordinator?

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            configureInteractivePopGesture()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configureInteractivePopGesture()
        }

        func configureInteractivePopGesture() {
            guard
                let navigationController = resolveNavigationController(),
                let gestureRecognizer = navigationController.interactivePopGestureRecognizer,
                let coordinator
            else { return }

            coordinator.navigationController = navigationController
            gestureRecognizer.delegate = coordinator
            gestureRecognizer.isEnabled = navigationController.viewControllers.count > 1
            prioritizeInteractivePop(overScrollGesturesIn: navigationController, popGesture: gestureRecognizer)
        }

        private func resolveNavigationController() -> UINavigationController? {
            if let navigationController {
                return navigationController
            }

            var currentParent = parent
            while let current = currentParent {
                if let nav = current as? UINavigationController {
                    return nav
                }
                if let nav = current.navigationController {
                    return nav
                }
                currentParent = current.parent
            }

            return view.window?.rootViewController?.firstNavigationControllerInHierarchy()
        }

        private func prioritizeInteractivePop(overScrollGesturesIn navigationController: UINavigationController, popGesture: UIGestureRecognizer) {
            for scrollView in navigationController.view.allDescendantScrollViews() {
                let pan = scrollView.panGestureRecognizer
                guard pan !== popGesture else { continue }
                pan.require(toFail: popGesture)
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigationController else { return false }
            return navigationController.viewControllers.count > 1
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

extension View {
    func enableInteractivePopGesture() -> some View {
        background(InteractivePopGestureConfigurator().frame(width: 0, height: 0))
    }

    // Backward-compatible alias used in Setlog flow views.
    func enableNavigationBackSwipeGesture() -> some View {
        enableInteractivePopGesture()
    }
}

private extension UIViewController {
    func firstNavigationControllerInHierarchy() -> UINavigationController? {
        if let nav = self as? UINavigationController {
            return nav
        }
        if let nav = navigationController {
            return nav
        }
        for child in children {
            if let nav = child.firstNavigationControllerInHierarchy() {
                return nav
            }
        }
        if let presentedViewController {
            return presentedViewController.firstNavigationControllerInHierarchy()
        }
        return nil
    }
}

private extension UIView {
    func allDescendantScrollViews() -> [UIScrollView] {
        var result: [UIScrollView] = []
        if let scrollView = self as? UIScrollView {
            result.append(scrollView)
        }
        for subview in subviews {
            result.append(contentsOf: subview.allDescendantScrollViews())
        }
        return result
    }
}
