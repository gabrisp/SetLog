import Foundation

// In-memory cache of user-confirmed command→exercise resolutions.
// Loaded once at startup, updated when the user picks a clarification choice.
// Consulted by WorkoutCommandInterpreter before any parser runs.
@MainActor
final class CommandResolutionCache {

    private var resolutions: [UserCommandResolutionDTO] = []
    private let repository: UserResolutionRepositoryProtocol

    init(repository: UserResolutionRepositoryProtocol) {
        self.repository = repository
    }

    func load() async {
        resolutions = (try? await repository.findAll()) ?? []
    }

    // Returns the best matching resolution for the given raw input, or nil.
    // Matching: normalized substring — "curl bayesian" matches stored "curl bayesian".
    // Falls back to word-set intersection for reordered inputs.
    func resolve(input: String) -> UserCommandResolutionDTO? {
        let normalized = normalize(input)
        guard !normalized.isEmpty else { return nil }

        // Exact match first
        if let exact = resolutions.first(where: { $0.rawInput == normalized }) {
            return exact
        }

        // Substring match
        if let sub = resolutions.first(where: { normalized.contains($0.rawInput) || $0.rawInput.contains(normalized) }) {
            return sub
        }

        // Word-set intersection (handles reordering: "bayesian curl" matches "curl bayesian")
        let inputWords = Set(normalized.split(separator: " ").map(String.init))
        guard inputWords.count >= 2 else { return nil }

        return resolutions
            .filter { dto in
                let storedWords = Set(dto.rawInput.split(separator: " ").map(String.init))
                let intersection = inputWords.intersection(storedWords)
                // Require at least 2 matching words and >50% overlap on both sides
                return intersection.count >= 2
                    && Double(intersection.count) / Double(inputWords.count) > 0.5
                    && Double(intersection.count) / Double(storedWords.count) > 0.5
            }
            .max(by: { $0.useCount < $1.useCount })
    }

    func incrementUseCount(id: UUID) async {
        try? await repository.incrementUseCount(id: id)
        await load()
    }

    func learn(rawInput: String, resolvedExerciseName: String, resolvedIntent: String) async {
        let normalized = normalize(rawInput)
        guard !normalized.isEmpty, !resolvedExerciseName.isEmpty else { return }

        try? await repository.save(
            rawInput: normalized,
            resolvedExerciseName: resolvedExerciseName,
            resolvedIntent: resolvedIntent
        )
        // Reload to keep cache fresh
        await load()
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
