import Foundation

final class LocalWorkoutCommandParser: WorkoutCommandParsingService {

    private static let confidenceThreshold: Double = 0.75

    func parse(input: String, context: WorkoutCommandContext) -> WorkoutCommandExecutionPlan {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if let plan = tryDeleteLastSet(normalized: normalized, context: context) { return plan }
        if let plan = tryDuplicateSetWithModifier(normalized: normalized, context: context) { return plan }
        if let plan = tryAddSetPattern(normalized: normalized, context: context) { return plan }
        if let plan = tryAddExercise(normalized: normalized, context: context) { return plan }

        return unknown(rawText: input)
    }

    // MARK: - Pattern matchers

    // "borra la última serie" / "elimina la última serie" / "delete the last set"
    private func tryDeleteLastSet(normalized: String, context: WorkoutCommandContext) -> WorkoutCommandExecutionPlan? {
        let triggers = ["borra la última serie", "elimina la última serie", "delete the last set", "remove last set"]
        guard triggers.contains(where: { normalized.contains($0) }) else { return nil }

        let command = ParsedWorkoutCommand.deleteSet(DeleteSetCommand(
            target: .lastTouchedSet,
            metadata: metadata(confidence: 0.95, summary: "Delete last set")
        ))
        return plan(command: command, confidence: 0.95)
    }

    // "añade una serie igual" / "add another set" optionally "con Xkg menos / X reps menos"
    private func tryDuplicateSetWithModifier(normalized: String, context: WorkoutCommandContext) -> WorkoutCommandExecutionPlan? {
        let duplicateTriggers = ["añade una serie igual", "otra serie igual", "add another set", "añade otra serie"]
        guard duplicateTriggers.contains(where: { normalized.contains($0) }) else { return nil }

        var modifier = WorkoutCommandModifier()
        modifier.weightDelta = extractWeightDelta(from: normalized)
        modifier.repsDelta = extractRepsDelta(from: normalized)

        let summary = buildModifierSummary(modifier: modifier, base: "Duplicate last set")
        let command = ParsedWorkoutCommand.duplicateSet(DuplicateSetCommand(
            target: .lastTouchedSet,
            modifier: (modifier.weightDelta != nil || modifier.repsDelta != nil) ? modifier : nil,
            metadata: metadata(confidence: 0.90, summary: summary)
        ))
        return plan(command: command, confidence: 0.90)
    }

    // "curl bayesian 8 reps 25kg" — exercise name + reps + weight pattern
    private func tryAddSetPattern(normalized: String, context: WorkoutCommandContext) -> WorkoutCommandExecutionPlan? {
        guard let parsed = extractExerciseRepsWeight(from: normalized) else { return nil }

        let set = ParsedSet(
            reps: parsed.reps,
            weight: parsed.weight,
            unit: parsed.unit ?? context.preferredWeightUnit
        )
        let command = ParsedWorkoutCommand.addSet(AddSetCommand(
            target: .exerciseName(parsed.exerciseName),
            set: set,
            metadata: metadata(confidence: 0.85, summary: "Add set to \(parsed.exerciseName)")
        ))
        return plan(command: command, confidence: 0.85)
    }

    // "añade el ejercicio pull" / "añádeme el curl bayesian" / "add exercise bench press"
    private func tryAddExercise(normalized: String, context: WorkoutCommandContext) -> WorkoutCommandExecutionPlan? {
        let triggers = ["añade el ejercicio", "añádeme el", "añade ", "add exercise", "add the exercise"]
        for trigger in triggers {
            if normalized.hasPrefix(trigger) {
                let name = String(normalized.dropFirst(trigger.count)).trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }

                let command = ParsedWorkoutCommand.addExercise(AddExerciseCommand(
                    name: name,
                    target: .currentWorkout,
                    initialSet: nil,
                    metadata: metadata(confidence: 0.80, summary: "Add exercise: \(name)")
                ))
                return plan(command: command, confidence: 0.80)
            }
        }
        return nil
    }

    // MARK: - Extraction helpers

    private func extractWeightDelta(from text: String) -> Double? {
        // Matches "con 10kg menos", "10kg menos", "con 10 kg menos"
        let pattern = #"con\s+(\d+(?:\.\d+)?)\s*kg\s+menos|(\d+(?:\.\d+)?)\s*kg\s+menos"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let fragment = String(text[match])
            let numPattern = #"(\d+(?:\.\d+)?)"#
            if let numMatch = fragment.range(of: numPattern, options: .regularExpression) {
                return -(Double(fragment[numMatch]) ?? 0)
            }
        }
        return nil
    }

    private func extractRepsDelta(from text: String) -> Int? {
        // Matches "elimina una repetición", "una rep menos", "one rep less"
        if text.contains("elimina una repetición") || text.contains("una rep menos") || text.contains("one rep less") {
            return -1
        }
        return nil
    }

    private struct ExerciseRepsWeight {
        var exerciseName: String
        var reps: Int?
        var weight: Double?
        var unit: String?
    }

    // Basic pattern: "<name> <N> reps <W>kg" or "<name> <N>x<W>"
    private func extractExerciseRepsWeight(from text: String) -> ExerciseRepsWeight? {
        // Pattern: word(s) followed by number reps number kg/lb
        let pattern = #"^(.+?)\s+(\d+)\s+reps?\s+(\d+(?:\.\d+)?)\s*(kg|lb)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges == 5
        else { return nil }

        func group(_ i: Int) -> String? {
            guard let range = Range(match.range(at: i), in: text) else { return nil }
            return String(text[range])
        }

        guard let name = group(1), let repsStr = group(2), let weightStr = group(3) else { return nil }
        return ExerciseRepsWeight(
            exerciseName: name.trimmingCharacters(in: .whitespaces),
            reps: Int(repsStr),
            weight: Double(weightStr),
            unit: group(4)
        )
    }

    private func buildModifierSummary(modifier: WorkoutCommandModifier, base: String) -> String {
        var parts: [String] = [base]
        if let wd = modifier.weightDelta { parts.append("\(wd > 0 ? "+" : "")\(wd)kg") }
        if let rd = modifier.repsDelta { parts.append("\(rd > 0 ? "+" : "")\(rd) reps") }
        return parts.joined(separator: ", ")
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

    private func plan(command: ParsedWorkoutCommand, confidence: Double) -> WorkoutCommandExecutionPlan {
        let meta = ParsedCommandMetadata(
            confidence: confidence,
            source: .localParser,
            needsConfirmation: false,
            userVisibleSummary: ""
        )
        return WorkoutCommandExecutionPlan(
            command: command,
            validationResult: .valid,
            metadata: meta
        )
    }

    private func unknown(rawText: String) -> WorkoutCommandExecutionPlan {
        WorkoutCommandExecutionPlan(
            command: .unknown(rawText: rawText),
            validationResult: .invalid(reason: "Command not recognized"),
            metadata: ParsedCommandMetadata(confidence: 0, source: .localParser, needsConfirmation: false, userVisibleSummary: "")
        )
    }
}
