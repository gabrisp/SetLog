import Foundation

@Observable
final class OnboardingViewModel {

    // TODO: Replace with real onboarding page model
    struct Page {
        let title: String
        let subtitle: String
    }

    let pages: [Page] = [
        Page(title: "Welcome to Setlog", subtitle: "Your minimal workout notebook."),
    ]

    var currentIndex: Int = 0

    var isLastPage: Bool { currentIndex >= pages.count - 1 }

    var onCompleted: (() -> Void)?

    func advance() {
        if isLastPage {
            complete()
        } else {
            currentIndex += 1
        }
    }

    func complete() {
        onCompleted?()
    }
}
