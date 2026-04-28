import SwiftUI
import UIKit

// MARK: - Native interactive pop — extended to left half of screen

private struct InteractivePopGestureConfigurator: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

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
                let nav = resolveNavigationController(),
                let gesture = nav.interactivePopGestureRecognizer,
                let coordinator
            else { return }

            coordinator.navigationController = nav
            gesture.delegate = coordinator
            gesture.isEnabled = nav.viewControllers.count > 1

            // Silence the original delegate so ours takes full control
            prioritizeInteractivePop(overScrollGesturesIn: nav, popGesture: gesture)
        }

        private func resolveNavigationController() -> UINavigationController? {
            if let nav = navigationController { return nav }
            var p = parent
            while let current = p {
                if let nav = current as? UINavigationController { return nav }
                if let nav = current.navigationController { return nav }
                p = current.parent
            }
            return view.window?.rootViewController?.firstNavigationControllerInHierarchy()
        }

        private func prioritizeInteractivePop(overScrollGesturesIn nav: UINavigationController, popGesture: UIGestureRecognizer) {
            for scrollView in nav.view.allDescendantScrollViews() {
                let pan = scrollView.panGestureRecognizer
                guard pan !== popGesture else { continue }
                pan.require(toFail: popGesture)
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
            guard let nav = navigationController, nav.viewControllers.count > 1 else { return false }
            // Allow from anywhere in the left half, not just the edge
            let x = gr.location(in: gr.view).x
            let halfWidth = (gr.view?.bounds.width ?? 0) / 2
            return x < halfWidth
        }

        func gestureRecognizer(_ gr: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

// MARK: - Forward interactive push (right half → push last Today)

/// Drives a push transition interactively from the right edge, mirroring the native pop.
final class ForwardInteractiveTransition: NSObject, UINavigationControllerDelegate {
    private var interactionController: UIPercentDrivenInteractiveTransition?
    private weak var nav: UINavigationController?
    private var panGesture: UIPanGestureRecognizer?
    var pushAction: (() -> Void)?

    func install(on nav: UINavigationController) {
        guard self.nav == nil else { return }
        self.nav = nav
        nav.delegate = self

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        nav.view.addGestureRecognizer(pan)
        panGesture = pan
    }

    // MARK: - Gesture

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let view = pan.view else { return }
        let width = view.bounds.width
        let tx = pan.translation(in: view).x
        let progress = min(max(-tx / width, 0), 1)

        switch pan.state {
        case .began:
            interactionController = UIPercentDrivenInteractiveTransition()
            interactionController?.completionCurve = .easeInOut
            pushAction?()

        case .changed:
            interactionController?.update(progress)

        case .ended, .cancelled:
            let vx = pan.velocity(in: view).x
            if vx < -300 || (progress > 0.4 && vx <= 0) {
                interactionController?.finish()
            } else {
                interactionController?.cancel()
            }
            interactionController = nil

        default:
            interactionController?.cancel()
            interactionController = nil
        }
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(
        _ nav: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        operation == .push ? PushFromRightAnimator() : nil
    }

    func navigationController(
        _ nav: UINavigationController,
        interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning
    ) -> (any UIViewControllerInteractiveTransitioning)? {
        interactionController
    }
}

extension ForwardInteractiveTransition: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
        guard let nav, nav.viewControllers.count == 1 else { return false }
        guard let pan = gr as? UIPanGestureRecognizer else { return false }
        let loc = pan.location(in: pan.view)
        let halfWidth = (pan.view?.bounds.width ?? 0) / 2
        guard loc.x > halfWidth else { return false }
        let vel = pan.velocity(in: pan.view)
        return vel.x < 0 && abs(vel.x) > abs(vel.y)
    }

    func gestureRecognizer(_ gr: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

// MARK: - Push animator (mirrors native pop: new screen slides in from right)

private final class PushFromRightAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using ctx: (any UIViewControllerContextTransitioning)?) -> TimeInterval { 0.35 }

    func animateTransition(using ctx: any UIViewControllerContextTransitioning) {
        guard
            let toVC = ctx.viewController(forKey: .to),
            let fromVC = ctx.viewController(forKey: .from)
        else { ctx.completeTransition(false); return }

        let container = ctx.containerView
        let width = container.bounds.width
        toVC.view.frame = ctx.finalFrame(for: toVC)
        toVC.view.transform = CGAffineTransform(translationX: width, y: 0)
        container.addSubview(toVC.view)

        UIView.animate(
            withDuration: transitionDuration(using: ctx),
            delay: 0,
            options: .curveEaseInOut
        ) {
            toVC.view.transform = .identity
            fromVC.view.transform = CGAffineTransform(translationX: -width * 0.3, y: 0)
        } completion: { _ in
            fromVC.view.transform = .identity
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
    }
}

// MARK: - ForwardSwipeConfigurator (installs ForwardInteractiveTransition on the nav)

private struct ForwardSwipeConfigurator: UIViewControllerRepresentable {
    let onSwipe: () -> Void

    func makeCoordinator() -> ForwardInteractiveTransition {
        let t = ForwardInteractiveTransition()
        t.pushAction = onSwipe
        return t
    }

    func makeUIViewController(context: Context) -> InstallerController {
        InstallerController()
    }

    func updateUIViewController(_ vc: InstallerController, context: Context) {
        context.coordinator.pushAction = onSwipe
        vc.install(coordinator: context.coordinator)
    }

    final class InstallerController: UIViewController {
        private weak var installed: ForwardInteractiveTransition?

        func install(coordinator: ForwardInteractiveTransition) {
            guard installed == nil else { return }
            if let nav = navigationController ?? parent?.navigationController {
                coordinator.install(on: nav)
                installed = coordinator
            }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // retry in case nav wasn't ready in updateUIViewController
            if let coordinator = (parent as? UIHostingController<AnyView>)?.rootView as? AnyObject as? ForwardInteractiveTransition {
                install(coordinator: coordinator)
            }
        }
    }
}

// MARK: - View modifiers

extension View {
    func enableInteractivePopGesture() -> some View {
        background(InteractivePopGestureConfigurator().frame(width: 0, height: 0))
    }

    func enableNavigationBackSwipeGesture() -> some View {
        enableInteractivePopGesture()
    }

    func enableWideBackSwipe() -> some View {
        enableInteractivePopGesture()
    }

    func enableForwardSwipe(action: @escaping () -> Void) -> some View {
        background(ForwardSwipeConfigurator(onSwipe: action).frame(width: 0, height: 0))
    }
}

// MARK: - Helpers

private extension UIViewController {
    func firstNavigationControllerInHierarchy() -> UINavigationController? {
        if let nav = self as? UINavigationController { return nav }
        if let nav = navigationController { return nav }
        for child in children {
            if let nav = child.firstNavigationControllerInHierarchy() { return nav }
        }
        if let nav = presentedViewController?.firstNavigationControllerInHierarchy() { return nav }
        return nil
    }
}

private extension UIView {
    func allDescendantScrollViews() -> [UIScrollView] {
        var result: [UIScrollView] = []
        if let sv = self as? UIScrollView { result.append(sv) }
        for sub in subviews { result.append(contentsOf: sub.allDescendantScrollViews()) }
        return result
    }
}
