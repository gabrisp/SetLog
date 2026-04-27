import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Uses Apple Foundation Models when available at runtime (iOS 26+).
// This parser only returns structured ParsedWorkoutCommand values and never mutates persistence directly.
final class FoundationModelsWorkoutCommandParser: WorkoutCommandParsingService {

    private let entitlementService: EntitlementServiceProtocol

    init(entitlementService: EntitlementServiceProtocol) {
        self.entitlementService = entitlementService
    }

    func parse(input: String, context: WorkoutCommandContext) async -> WorkoutCommandExecutionPlan {
        let aiParsingEnabledForAllUsers = true
        if !aiParsingEnabledForAllUsers && !entitlementService.canUse(.aiCommandParsing) {
            return proGatePlan(input: input)
        }

#if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            return unavailablePlan(input: input, reason: "Foundation Models require iOS 26+")
        }

        return await parseWithFoundationModels(input: input, context: context)
#else
        return unavailablePlan(input: input, reason: "FoundationModels framework unavailable")
#endif
    }

    private func unavailablePlan(input: String, reason: String) -> WorkoutCommandExecutionPlan {
        WorkoutCommandExecutionPlan(
            command: .unknown(rawText: input),
            validationResult: .invalid(reason: reason),
            metadata: ParsedCommandMetadata(
                confidence: 0,
                source: .foundationModels,
                needsConfirmation: true,
                userVisibleSummary: "Foundation Models unavailable"
            )
        )
    }

    private func proGatePlan(input: String) -> WorkoutCommandExecutionPlan {
        WorkoutCommandExecutionPlan(
            command: .unknown(rawText: input),
            validationResult: .requiresProFeature(feature: .aiCommandParsing),
            metadata: ParsedCommandMetadata(
                confidence: 0,
                source: .foundationModels,
                needsConfirmation: true,
                userVisibleSummary: "AI parsing requires Pro"
            )
        )
    }
}

private struct FMCommandPayload: Decodable {
    var intent: String
    var target: String?
    var exerciseName: String?
    var equipment: String?
    var sets: Int?
    var reps: Int?
    var weight: Double?
    var unit: String?
    var weightDelta: Double?
    var repsDelta: Int?
    var confidence: Double?
    var summary: String?
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private extension FoundationModelsWorkoutCommandParser {

    func parseWithFoundationModels(input: String, context: WorkoutCommandContext) async -> WorkoutCommandExecutionPlan {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            return unavailablePlan(input: input, reason: "On-device model is not available")
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You convert natural-language workout commands into JSON only.
            Supported intents: add_exercise, add_set, add_multiple_sets, duplicate_set, delete_set, unknown.
            Return strict JSON object with keys:
            intent, target, exerciseName, equipment, sets, reps, weight, unit, weightDelta, repsDelta, confidence, summary.
            target can be: current_workout, exercise_name, last_touched_set, last_touched_exercise, previous_exercise, selected_exercise.
            For bodyweight, set unit to bodyweight and weight to 0.
            Confidence must be 0...1.
            """
        )

        do {
            let response = try await session.respond(to: buildPrompt(input: input, context: context))
            guard let payload = decodePayload(from: response.content) else {
                return invalidPlan(input: input, reason: "Could not decode FM response JSON")
            }
            return mapPayload(payload, rawInput: input, preferredUnit: context.preferredWeightUnit)
        } catch {
            return invalidPlan(input: input, reason: error.localizedDescription)
        }
    }

    func buildPrompt(input: String, context: WorkoutCommandContext) -> String {
        """
        Input command: \(input)

        Context:
        - dayKey: \(context.dayKey)
        - preferredWeightUnit: \(context.preferredWeightUnit)
        - selectedWorkoutSessionID: \(context.selectedWorkoutSessionID?.uuidString ?? "none")
        - lastTouchedExerciseID: \(context.lastTouchedExerciseID?.uuidString ?? "none")
        - lastTouchedSetID: \(context.lastTouchedSetID?.uuidString ?? "none")

        Respond with JSON only.
        """
    }

    func decodePayload(from raw: String) -> FMCommandPayload? {
        var cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleaned.hasPrefix("{"), let firstBrace = cleaned.firstIndex(of: "{"), let lastBrace = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[firstBrace...lastBrace])
        }

        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(FMCommandPayload.self, from: data)
    }

    func mapPayload(_ payload: FMCommandPayload, rawInput: String, preferredUnit: String) -> WorkoutCommandExecutionPlan {
        let confidence = max(0, min(1, payload.confidence ?? 0.6))
        let summary = payload.summary ?? "Interpreted command"
        let metadata = ParsedCommandMetadata(
            confidence: confidence,
            source: .foundationModels,
            needsConfirmation: confidence < 0.75,
            userVisibleSummary: summary
        )

        let target = parseTarget(raw: payload.target, exerciseName: payload.exerciseName)

        switch payload.intent.lowercased() {
        case "add_exercise":
            guard let name = payload.exerciseName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                return invalidPlan(input: rawInput, reason: "Missing exercise name")
            }
            let command = ParsedWorkoutCommand.addExercise(
                AddExerciseCommand(name: name, target: .currentWorkout, initialSet: nil, metadata: metadata)
            )
            return validPlan(command: command, metadata: metadata)

        case "add_set":
            guard let reps = payload.reps else {
                return invalidPlan(input: rawInput, reason: "Missing reps for add_set")
            }
            let unit = (payload.unit?.isEmpty == false ? payload.unit! : preferredUnit)
            let parsedSet = ParsedSet(
                reps: reps,
                weight: payload.weight,
                unit: payload.unit == "bodyweight" ? "bodyweight" : unit,
                notes: payload.equipment
            )
            let command = ParsedWorkoutCommand.addSet(
                AddSetCommand(target: target, set: parsedSet, metadata: metadata)
            )
            return validPlan(command: command, metadata: metadata)

        case "add_multiple_sets":
            guard let reps = payload.reps else {
                return invalidPlan(input: rawInput, reason: "Missing reps for add_multiple_sets")
            }
            let count = max(2, payload.sets ?? 2)
            let unit = (payload.unit?.isEmpty == false ? payload.unit! : preferredUnit)
            let set = ParsedSet(
                reps: reps,
                weight: payload.weight,
                unit: payload.unit == "bodyweight" ? "bodyweight" : unit,
                notes: payload.equipment
            )
            let command = ParsedWorkoutCommand.addMultipleSets(
                AddMultipleSetsCommand(target: target, sets: Array(repeating: set, count: count), metadata: metadata)
            )
            return validPlan(command: command, metadata: metadata)

        case "duplicate_set":
            var modifier: WorkoutCommandModifier?
            if payload.weightDelta != nil || payload.repsDelta != nil {
                modifier = WorkoutCommandModifier(weightDelta: payload.weightDelta, repsDelta: payload.repsDelta)
            }
            let command = ParsedWorkoutCommand.duplicateSet(
                DuplicateSetCommand(target: target, modifier: modifier, metadata: metadata)
            )
            return validPlan(command: command, metadata: metadata)

        case "delete_set":
            let command = ParsedWorkoutCommand.deleteSet(
                DeleteSetCommand(target: .lastTouchedSet, metadata: metadata)
            )
            return validPlan(command: command, metadata: metadata)

        default:
            return invalidPlan(input: rawInput, reason: "Unknown intent \(payload.intent)")
        }
    }

    func parseTarget(raw: String?, exerciseName: String?) -> WorkoutCommandTarget {
        guard let raw else {
            if let exerciseName, !exerciseName.isEmpty {
                return .exerciseName(exerciseName)
            }
            return .lastTouchedSet
        }

        switch raw.lowercased() {
        case "current_workout":
            return .currentWorkout
        case "exercise_name":
            if let exerciseName, !exerciseName.isEmpty { return .exerciseName(exerciseName) }
            return .lastTouchedExercise
        case "last_touched_set":
            return .lastTouchedSet
        case "last_touched_exercise":
            return .lastTouchedExercise
        case "previous_exercise":
            return .previousExercise
        case "selected_exercise":
            return .selectedExercise
        default:
            return .lastTouchedSet
        }
    }

    func validPlan(command: ParsedWorkoutCommand, metadata: ParsedCommandMetadata) -> WorkoutCommandExecutionPlan {
        WorkoutCommandExecutionPlan(command: command, validationResult: .valid, metadata: metadata)
    }

    func invalidPlan(input: String, reason: String) -> WorkoutCommandExecutionPlan {
        WorkoutCommandExecutionPlan(
            command: .unknown(rawText: input),
            validationResult: .invalid(reason: reason),
            metadata: ParsedCommandMetadata(
                confidence: 0,
                source: .foundationModels,
                needsConfirmation: true,
                userVisibleSummary: "Couldn't interpret command"
            )
        )
    }
}
#endif
