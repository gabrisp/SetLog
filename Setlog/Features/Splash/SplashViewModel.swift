import Foundation

@Observable
final class SplashViewModel {

    private let displayDuration: TimeInterval
    var onFinished: (() -> Void)?

    init(displayDuration: TimeInterval = 1.5) {
        self.displayDuration = displayDuration
    }

    func start() {
        Task {
            try? await Task.sleep(for: .seconds(displayDuration))
            await MainActor.run { onFinished?() }
        }
    }
}
