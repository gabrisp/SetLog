import Foundation

final class LocalWorkoutCommandParser: WorkoutCommandParsingService {

    private static let confidenceThreshold: Double = 0.75

    func parse(input: String, context: WorkoutCommandContext) async -> WorkoutCommandExecutionPlan {
        parseSynchronously(input: input, context: context)
    }

    private func parseSynchronously(input: String, context: WorkoutCommandContext) -> WorkoutCommandExecutionPlan {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalize(trimmed)

        guard !normalized.isEmpty else {
            return unknown(rawText: input)
        }

        if let plan = tryDeleteLastSet(normalized: normalized) { return plan }
        if let plan = tryDuplicateSetWithModifier(normalized: normalized) { return plan }
        if let plan = tryAddCountOnlySets(normalized: normalized) { return plan }
        if let plan = tryAddMultipleSetsPattern(normalized: normalized, context: context) { return plan }
        if let plan = tryAddSingleSetPattern(normalized: normalized, context: context) { return plan }
        if let plan = tryAddExercise(normalized: normalized) { return plan }
        if let plan = tryImplicitAddExerciseOrSet(normalized: normalized, context: context) { return plan }

        return unknown(rawText: input)
    }

    // MARK: - Pattern matchers

    private func tryDeleteLastSet(normalized: String) -> WorkoutCommandExecutionPlan? {
        let triggers = [
            "borra la ultima serie", "elimina la ultima serie", "borra ultima serie", "elimina ultima serie",
            "delete last set", "delete the last set", "remove last set", "remove the last set"
        ]
        guard triggers.contains(where: normalized.contains) else { return nil }

        let meta = metadata(confidence: 0.95, summary: "Delete last set")
        let command = ParsedWorkoutCommand.deleteSet(DeleteSetCommand(target: .lastTouchedSet, metadata: meta))
        return plan(command: command, metadata: meta)
    }

    private func tryDuplicateSetWithModifier(normalized: String) -> WorkoutCommandExecutionPlan? {
        let hasDuplicateIntent =
            normalized.contains("otra igual")
            || normalized.contains("serie igual")
            || normalized.contains("same set")
            || normalized.contains("same again")
            || normalized.contains("add another set")
            || normalized.contains("another set")
            || normalized.contains("otra serie")
        guard hasDuplicateIntent else { return nil }

        var target: WorkoutCommandTarget = .lastTouchedSet
        if normalized.contains("ejercicio anterior") || normalized.contains("previous exercise") {
            target = .previousExercise
        } else if normalized.contains("este ejercicio") || normalized.contains("this exercise") {
            target = .selectedExercise
        }

        var modifier = WorkoutCommandModifier()
        modifier.weightDelta = extractWeightDelta(from: normalized)
        modifier.repsDelta = extractRepsDelta(from: normalized)

        let hasModifier = modifier.weightDelta != nil || modifier.repsDelta != nil
        let summary = buildModifierSummary(modifier: modifier, base: "Duplicate set")
        let meta = metadata(confidence: hasModifier ? 0.92 : 0.95, summary: summary)
        let command = ParsedWorkoutCommand.duplicateSet(
            DuplicateSetCommand(target: target, modifier: hasModifier ? modifier : nil, metadata: meta)
        )
        return plan(command: command, metadata: meta)
    }

    private func tryAddCountOnlySets(normalized: String) -> WorkoutCommandExecutionPlan? {
        let pattern = #"(?:(?:anade|anado|anadir|add|haz|hazme|do)\s+)?(?:(\d+|una|one)\s+)?(?:series|serie|sets?|set)\b"#
        guard let groups = captureGroups(pattern: pattern, in: normalized), groups.count >= 2 else {
            return nil
        }

        let countToken = groups[1]
        let count: Int
        if countToken == "una" || countToken == "one" || countToken.isEmpty {
            count = 1
        } else {
            guard let parsed = Int(countToken), parsed > 0 else { return nil }
            count = parsed
        }

        guard normalized.contains("serie") || normalized.contains("set") else { return nil }
        guard normalized.contains("anade")
                || normalized.contains("anado")
                || normalized.contains("anadir")
                || normalized.contains("add")
                || normalized.contains("haz")
                || normalized.contains("hazme")
                || normalized.contains("do ")
                || normalized == "serie"
                || normalized == "set" else {
            return nil
        }

        var target: WorkoutCommandTarget = .lastTouchedExercise
        if normalized.contains("este ejercicio") || normalized.contains("this exercise") {
            target = .selectedExercise
        } else if normalized.contains("ejercicio anterior") || normalized.contains("previous exercise") {
            target = .previousExercise
        }

        let emptySet = ParsedSet(reps: nil, weight: nil, unit: nil)
        let sets = Array(repeating: emptySet, count: count)
        let summary = count == 1 ? "Add 1 set" : "Add \(count) sets"
        let meta = metadata(confidence: 0.91, summary: summary)
        let command = ParsedWorkoutCommand.addMultipleSets(
            AddMultipleSetsCommand(target: target, sets: sets, metadata: meta)
        )
        return plan(command: command, metadata: meta)
    }

    private func tryAddMultipleSetsPattern(normalized: String, context: WorkoutCommandContext) -> WorkoutCommandExecutionPlan? {
        let pattern = #"^(.+?)\s+(\d+)\s*x\s*(\d+)\s+((?:\d+(?:[\.,]\d+)?)\s*(?:kg|lb)|peso corporal|bodyweight)(?:\s+(.+))?$"#
        guard let groups = captureGroups(pattern: pattern, in: normalized), groups.count >= 5 else { return nil }

        let exerciseName = groups[1].trimmingCharacters(in: .whitespaces)
        guard let setsCount = Int(groups[2]), let reps = Int(groups[3]) else { return nil }
        guard setsCount > 1 else { return nil }

        let parsedWeight = parseWeightToken(groups[4], preferredUnit: context.preferredWeightUnit)
        guard let parsedWeight else { return nil }

        var sets: [ParsedSet] = []
        sets.reserveCapacity(setsCount)
        for _ in 0..<setsCount {
            sets.append(ParsedSet(reps: reps, weight: parsedWeight.weight, unit: parsedWeight.unit))
        }

        let meta = metadata(confidence: 0.93, summary: "Add \(setsCount) sets to \(exerciseName)")
        let command = ParsedWorkoutCommand.addMultipleSets(
            AddMultipleSetsCommand(target: .exerciseName(exerciseName), sets: sets, metadata: meta)
        )
        return plan(command: command, metadata: meta)
    }

    private func tryAddSingleSetPattern(normalized: String, context: WorkoutCommandContext) -> WorkoutCommandExecutionPlan? {
        if let direct = parseNameRepsWeightPattern(normalized: normalized, preferredUnit: context.preferredWeightUnit) {
            let meta = metadata(confidence: direct.confidence, summary: "Add set to \(direct.exerciseName)")
            let command = ParsedWorkoutCommand.addSet(
                AddSetCommand(target: .exerciseName(direct.exerciseName), set: direct.set, metadata: meta)
            )
            return plan(command: command, metadata: meta)
        }

        return nil
    }

    private func parseNameRepsWeightPattern(normalized: String, preferredUnit: String) -> (exerciseName: String, set: ParsedSet, confidence: Double)? {
        let repsPattern = #"^(.+?)\s+(\d+)\s*(?:reps?|rep|repeticiones?|repeticion)\s+((?:\d+(?:[\.,]\d+)?)\s*(?:kg|lb)|peso corporal|bodyweight)(?:\s+(.+))?$"#
        if let groups = captureGroups(pattern: repsPattern, in: normalized), groups.count >= 5 {
            let exercise = groups[1].trimmingCharacters(in: .whitespaces)
            guard let reps = Int(groups[2]) else { return nil }
            guard let weight = parseWeightToken(groups[3], preferredUnit: preferredUnit) else { return nil }
            let equipment = groups[4].isEmpty ? nil : groups[4].trimmingCharacters(in: .whitespaces)

            return (
                exerciseName: exercise,
                set: ParsedSet(reps: reps, weight: weight.weight, unit: weight.unit, notes: equipment),
                confidence: 0.90
            )
        }

        let compactPattern = #"^(.+?)\s+(\d+)\s*x\s*(\d+(?:[\.,]\d+)?)(?:\s*(kg|lb))?(?:\s+(.+))?$"#
        if let groups = captureGroups(pattern: compactPattern, in: normalized), groups.count >= 6 {
            let exercise = groups[1].trimmingCharacters(in: .whitespaces)
            guard let reps = Int(groups[2]) else { return nil }
            let weightRaw = groups[3].replacingOccurrences(of: ",", with: ".")
            guard let weight = Double(weightRaw) else { return nil }
            let unit = groups[4].isEmpty ? preferredUnit : groups[4]
            let equipment = groups[5].isEmpty ? nil : groups[5].trimmingCharacters(in: .whitespaces)

            return (
                exerciseName: exercise,
                set: ParsedSet(reps: reps, weight: weight, unit: unit, notes: equipment),
                confidence: 0.86
            )
        }

        return nil
    }

    private func tryAddExercise(normalized: String) -> WorkoutCommandExecutionPlan? {
        let prefixes = [
            "anademe el", "anade el", "anade ejercicio", "anade el ejercicio", "anade ",
            "add exercise", "add the exercise", "add "
        ]

        for prefix in prefixes {
            guard normalized.hasPrefix(prefix) else { continue }
            let rawName = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            guard !rawName.isEmpty else { continue }

            let name = rawName
                .replacingOccurrences(of: "^el\\s+", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^the\\s+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            let meta = metadata(confidence: 0.84, summary: "Add exercise: \(name)")
            let command = ParsedWorkoutCommand.addExercise(
                AddExerciseCommand(name: name, target: .currentWorkout, initialSet: nil, metadata: meta)
            )
            return plan(command: command, metadata: meta)
        }

        return nil
    }

    private func tryImplicitAddExerciseOrSet(normalized: String, context: WorkoutCommandContext) -> WorkoutCommandExecutionPlan? {
        // Example: "sentadilla 5 100kg"
        let looseSetPattern = #"^(.+?)\s+(\d+)\s+((?:\d+(?:[\.,]\d+)?)\s*(?:kg|lb)|peso corporal|bodyweight)$"#
        if let groups = captureGroups(pattern: looseSetPattern, in: normalized), groups.count >= 4 {
            let name = groups[1].trimmingCharacters(in: .whitespaces)
            guard let reps = Int(groups[2]), let weightToken = parseWeightToken(groups[3], preferredUnit: context.preferredWeightUnit) else {
                return nil
            }

            let parsedSet = ParsedSet(reps: reps, weight: weightToken.weight, unit: weightToken.unit)
            let meta = metadata(confidence: 0.86, summary: "Add set to \(name)")
            let command = ParsedWorkoutCommand.addSet(
                AddSetCommand(target: .exerciseName(name), set: parsedSet, metadata: meta)
            )
            return plan(command: command, metadata: meta)
        }

        // Last-resort intent: if text looks like an exercise label, add exercise.
        let blockedTokens = [
            "borra", "elimina", "delete", "remove", "clear", "settings", "ajustes", "calendar", "calendario",
            "help", "ayuda", "abre", "open ", "cierra", "close "
        ]
        let isBlocked = blockedTokens.contains(where: normalized.contains)
        guard !isBlocked, normalized.count >= 3 else { return nil }

        let words = normalized.split(separator: " ")
        guard !words.isEmpty, words.count <= 12 else { return nil }

        let cleanedName = normalized
            .replacingOccurrences(of: "^quiero\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^hacer\\s+", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let meta = metadata(confidence: 0.88, summary: "Add exercise: \(cleanedName)")
        let command = ParsedWorkoutCommand.addExercise(
            AddExerciseCommand(name: cleanedName, target: .currentWorkout, initialSet: nil, metadata: meta)
        )
        return plan(command: command, metadata: meta)
    }

    // MARK: - Extraction helpers

    private func normalize(_ input: String) -> String {
        input
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractWeightDelta(from text: String) -> Double? {
        let pattern = #"(?:(?:con|with)\s*)?(\d+(?:[\.,]\d+)?)\s*(kg|lb)\s*(menos|less|mas|more)"#
        if let groups = captureGroups(pattern: pattern, in: text), groups.count >= 4 {
            let rawNumber = groups[1].replacingOccurrences(of: ",", with: ".")
            guard let amount = Double(rawNumber) else { return nil }

            let direction = groups[3]
            if direction == "menos" || direction == "less" {
                return -amount
            }
            return amount
        }

        let lowerPattern = #"(?:bajale|baja|reduce|lower)\s*(?:en|by)?\s*(\d+(?:[\.,]\d+)?)\s*(kg|lb)"#
        if let groups = captureGroups(pattern: lowerPattern, in: text), groups.count >= 2 {
            let rawNumber = groups[1].replacingOccurrences(of: ",", with: ".")
            if let amount = Double(rawNumber) {
                return -amount
            }
        }

        let raisePattern = #"(?:subele|sube|increase|raise)\s*(?:en|by)?\s*(\d+(?:[\.,]\d+)?)\s*(kg|lb)"#
        if let groups = captureGroups(pattern: raisePattern, in: text), groups.count >= 2 {
            let rawNumber = groups[1].replacingOccurrences(of: ",", with: ".")
            if let amount = Double(rawNumber) {
                return amount
            }
        }

        return nil
    }

    private func extractRepsDelta(from text: String) -> Int? {
        let repLessPhrases = [
            "elimina una repeticion", "una repeticion menos", "one rep less", "one less rep", "remove one rep"
        ]
        if repLessPhrases.contains(where: text.contains) {
            return -1
        }

        let repMorePhrases = [
            "una repeticion mas", "one rep more", "one more rep", "add one rep"
        ]
        if repMorePhrases.contains(where: text.contains) {
            return 1
        }

        return nil
    }

    private func parseWeightToken(_ token: String, preferredUnit: String) -> (weight: Double, unit: String)? {
        let normalized = token.trimmingCharacters(in: .whitespaces)
        if normalized == "peso corporal" || normalized == "bodyweight" {
            return (0, "bodyweight")
        }

        let pattern = #"^(\d+(?:[\.,]\d+)?)\s*(kg|lb)?$"#
        guard let groups = captureGroups(pattern: pattern, in: normalized), groups.count >= 3 else { return nil }
        let rawNumber = groups[1].replacingOccurrences(of: ",", with: ".")
        guard let weight = Double(rawNumber) else { return nil }
        let unit = groups[2].isEmpty ? preferredUnit : groups[2]
        return (weight, unit)
    }

    private func captureGroups(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }

        var groups: [String] = []
        for idx in 0..<match.numberOfRanges {
            guard let range = Range(match.range(at: idx), in: text) else {
                groups.append("")
                continue
            }
            groups.append(String(text[range]))
        }
        return groups
    }

    private func buildModifierSummary(modifier: WorkoutCommandModifier, base: String) -> String {
        var parts: [String] = [base]
        if let weightDelta = modifier.weightDelta {
            let sign = weightDelta > 0 ? "+" : ""
            parts.append("\(sign)\(weightDelta)kg")
        }
        if let repsDelta = modifier.repsDelta {
            let sign = repsDelta > 0 ? "+" : ""
            parts.append("\(sign)\(repsDelta) reps")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Factories

    private func metadata(confidence: Double, summary: String) -> ParsedCommandMetadata {
        ParsedCommandMetadata(
            confidence: confidence,
            source: .localParser,
            needsConfirmation: confidence < Self.confidenceThreshold,
            userVisibleSummary: summary
        )
    }

    private func plan(command: ParsedWorkoutCommand, metadata: ParsedCommandMetadata) -> WorkoutCommandExecutionPlan {
        WorkoutCommandExecutionPlan(
            command: command,
            validationResult: .valid,
            metadata: metadata
        )
    }

    private func unknown(rawText: String) -> WorkoutCommandExecutionPlan {
        WorkoutCommandExecutionPlan(
            command: .unknown(rawText: rawText),
            validationResult: .invalid(reason: "Command not recognized"),
            metadata: ParsedCommandMetadata(
                confidence: 0,
                source: .localParser,
                needsConfirmation: true,
                userVisibleSummary: "Command not recognized"
            )
        )
    }
}
