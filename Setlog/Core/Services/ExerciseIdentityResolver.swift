import Foundation

@MainActor
struct ExerciseIdentityResolution {
    var savedExerciseID: UUID
    var canonicalName: String
    var equipment: String?
    var primaryMusclesText: String?
    var secondaryMusclesText: String?
    var aiPrimaryMusclesText: String?
    var aiSecondaryMusclesText: String?
    var confidence: Double
    var source: Source

    enum Source {
        case alias
        case exact
        case catalog
        case semantic
        case created
    }
}

@MainActor
final class ExerciseIdentityResolver {

    private let exerciseRepository: ExerciseRepositoryProtocol
    private let resolutionCache: CommandResolutionCache?

    init(
        exerciseRepository: ExerciseRepositoryProtocol,
        resolutionCache: CommandResolutionCache? = nil
    ) {
        self.exerciseRepository = exerciseRepository
        self.resolutionCache = resolutionCache
    }

    func resolve(
        rawInput: String,
        hintedExerciseName: String?,
        hintedEquipment: String?,
        aiPrimaryMusclesText: String? = nil,
        aiSecondaryMusclesText: String? = nil
    ) async throws -> ExerciseIdentityResolution {
        let baseName = pickBaseName(rawInput: rawInput, hintedExerciseName: hintedExerciseName)
        let normalizedBase = Self.normalize(baseName)
        let savedExercises = try await exerciseRepository.fetchSavedExercises()

        if let alias = resolutionCache?.resolve(input: rawInput),
           let matched = savedExercises.first(where: { $0.normalizedName == Self.normalize(alias.resolvedExerciseName) }) {
            try await persistMetadata(
                savedExercise: matched,
                equipment: hintedEquipment,
                catalogMatch: nil,
                aiPrimaryMusclesText: aiPrimaryMusclesText,
                aiSecondaryMusclesText: aiSecondaryMusclesText
            )
            return resolved(from: matched, source: .alias, confidence: 0.98)
        }

        if let exact = savedExercises.first(where: { $0.normalizedName == normalizedBase }) {
            try await persistMetadata(
                savedExercise: exact,
                equipment: hintedEquipment,
                catalogMatch: nil,
                aiPrimaryMusclesText: aiPrimaryMusclesText,
                aiSecondaryMusclesText: aiSecondaryMusclesText
            )
            return resolved(from: exact, source: .exact, confidence: 0.96)
        }

        let catalogMatch = ExerciseCatalogResolver.resolve(
            commandText: baseName,
            hintedEquipment: hintedEquipment
        )

        if let catalogMatch {
            let catalogNormalized = Self.normalize(catalogMatch.canonicalName)
            if let existing = savedExercises.first(where: { $0.normalizedName == catalogNormalized }) {
                try await persistMetadata(
                    savedExercise: existing,
                    equipment: hintedEquipment,
                    catalogMatch: catalogMatch,
                    aiPrimaryMusclesText: aiPrimaryMusclesText,
                    aiSecondaryMusclesText: aiSecondaryMusclesText
                )
                return resolved(from: existing, source: .catalog, confidence: max(0.85, catalogMatch.confidence))
            }

            let created = try await exerciseRepository.createSavedExercise(
                name: catalogMatch.canonicalName,
                equipment: hintedEquipment ?? catalogMatch.equipment
            )
            try await persistMetadata(
                savedExercise: created,
                equipment: hintedEquipment ?? catalogMatch.equipment,
                catalogMatch: catalogMatch,
                aiPrimaryMusclesText: aiPrimaryMusclesText,
                aiSecondaryMusclesText: aiSecondaryMusclesText
            )
            if let alias = resolutionCache {
                await alias.learn(rawInput: rawInput, resolvedExerciseName: catalogMatch.canonicalName, resolvedIntent: "add_exercise")
            }
            let refreshed = try await exerciseRepository.fetchSavedExercise(id: created.id) ?? created
            return resolved(from: refreshed, source: .created, confidence: max(0.78, catalogMatch.confidence))
        }

        if let semantic = bestSemanticMatch(
            among: savedExercises,
            name: baseName,
            hintedEquipment: hintedEquipment
        ) {
            try await persistMetadata(
                savedExercise: semantic,
                equipment: hintedEquipment,
                catalogMatch: nil,
                aiPrimaryMusclesText: aiPrimaryMusclesText,
                aiSecondaryMusclesText: aiSecondaryMusclesText
            )
            return resolved(from: semantic, source: .semantic, confidence: 0.7)
        }

        let created = try await exerciseRepository.createSavedExercise(
            name: baseName,
            equipment: hintedEquipment
        )
        try await persistMetadata(
            savedExercise: created,
            equipment: hintedEquipment,
            catalogMatch: nil,
            aiPrimaryMusclesText: aiPrimaryMusclesText,
            aiSecondaryMusclesText: aiSecondaryMusclesText
        )
        if let alias = resolutionCache {
            await alias.learn(rawInput: rawInput, resolvedExerciseName: baseName, resolvedIntent: "add_exercise")
        }
        let refreshed = try await exerciseRepository.fetchSavedExercise(id: created.id) ?? created
        return resolved(from: refreshed, source: .created, confidence: 0.62)
    }

    private func bestSemanticMatch(
        among savedExercises: [SavedExerciseDTO],
        name: String,
        hintedEquipment: String?
    ) -> SavedExerciseDTO? {
        let nameNormalized = Self.normalize(name)
        let nameTokens = Self.tokens(nameNormalized)
        guard !nameTokens.isEmpty else { return nil }

        var best: (item: SavedExerciseDTO, score: Double)?

        for item in savedExercises {
            let exerciseTokens = Self.tokens(item.normalizedName)
            guard !exerciseTokens.isEmpty else { continue }

            let overlap = Double(nameTokens.intersection(exerciseTokens).count)
            let coverage = overlap / Double(nameTokens.count)
            var score = coverage

            if let hintedEquipment,
               let itemEquipment = item.equipment,
               Self.normalize(itemEquipment) == Self.normalize(hintedEquipment) {
                score += 0.2
            }

            if best == nil || score > best!.score {
                best = (item, score)
            }
        }

        guard let best, best.score >= 0.75 else { return nil }
        return best.item
    }

    private func persistMetadata(
        savedExercise: SavedExerciseDTO,
        equipment: String?,
        catalogMatch: ExerciseCatalogMatch?,
        aiPrimaryMusclesText: String?,
        aiSecondaryMusclesText: String?
    ) async throws {
        let catalogPrimary = catalogMatch?.primaryMusclesText
        let catalogSecondary = catalogMatch?.secondaryMusclesText

        let resolvedEquipment = equipment ?? catalogMatch?.equipment ?? savedExercise.equipment

        let aiPrimary = aiPrimaryMusclesText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let aiSecondary = aiSecondaryMusclesText?.trimmingCharacters(in: .whitespacesAndNewlines)

        try await exerciseRepository.updateSavedExercise(
            id: savedExercise.id,
            name: nil,
            equipment: resolvedEquipment,
            primaryMusclesText: catalogPrimary,
            secondaryMusclesText: catalogSecondary,
            aiPrimaryMusclesText: aiPrimary?.isEmpty == false ? aiPrimary : nil,
            aiSecondaryMusclesText: aiSecondary?.isEmpty == false ? aiSecondary : nil
        )
    }

    private func resolved(
        from savedExercise: SavedExerciseDTO,
        source: ExerciseIdentityResolution.Source,
        confidence: Double
    ) -> ExerciseIdentityResolution {
        ExerciseIdentityResolution(
            savedExerciseID: savedExercise.id,
            canonicalName: savedExercise.name,
            equipment: savedExercise.equipment,
            primaryMusclesText: savedExercise.primaryMusclesText,
            secondaryMusclesText: savedExercise.secondaryMusclesText,
            aiPrimaryMusclesText: savedExercise.aiPrimaryMusclesText,
            aiSecondaryMusclesText: savedExercise.aiSecondaryMusclesText,
            confidence: confidence,
            source: source
        )
    }

    private func pickBaseName(rawInput: String, hintedExerciseName: String?) -> String {
        let hinted = hintedExerciseName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !hinted.isEmpty { return hinted }

        let raw = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return "Exercise" }

        return raw
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func tokens(_ normalized: String) -> Set<String> {
        Set(
            normalized
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }
}
