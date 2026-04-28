import Foundation

@Observable
final class SplashViewModel {

    private let displayDuration: TimeInterval
    var onFinished: (() -> Void)?

    init(displayDuration: TimeInterval = 1.5) {
        self.displayDuration = displayDuration
    }

    func start() {
        print("[SPLASH_VM] start displayDuration=\(displayDuration)")
        Task {
            try? await Task.sleep(for: .seconds(displayDuration))
            print("[SPLASH_VM] timer fired -> calling onFinished")
            await MainActor.run { onFinished?() }
        }
    }
}
