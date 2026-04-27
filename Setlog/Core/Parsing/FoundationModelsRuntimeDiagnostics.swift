import Foundation

struct FoundationModelsDiagnosticsSnapshot: Sendable {
    var lastAttemptAt: Date? = nil
    var lastInputPreview: String = ""
    var lastPath: String = "never"
    var lastOutcome: String = "never"
    var lastReason: String? = nil
}

@MainActor
final class FoundationModelsRuntimeDiagnostics {
    static let shared = FoundationModelsRuntimeDiagnostics()

    private var snapshot = FoundationModelsDiagnosticsSnapshot()

    func recordAttempt(input: String) async {
        snapshot.lastAttemptAt = Date()
        snapshot.lastInputPreview = String(input.prefix(120))
        snapshot.lastPath = "foundation-models"
        snapshot.lastOutcome = "attempted"
        snapshot.lastReason = nil
    }

    func recordResult(path: String, outcome: String, reason: String?) async {
        snapshot.lastPath = path
        snapshot.lastOutcome = outcome
        snapshot.lastReason = reason
    }

    func current() async -> FoundationModelsDiagnosticsSnapshot {
        snapshot
    }
}
