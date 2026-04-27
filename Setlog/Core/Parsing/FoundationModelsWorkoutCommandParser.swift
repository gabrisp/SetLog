import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Uses Apple Foundation Models when available at runtime (iOS 26+).
// This parser only returns structured ParsedWorkoutCommand values and never mutates persistence directly.
final class FoundationModelsWorkoutCommandParser: WorkoutCommandParsingService {

    private let entitlementService: EntitlementServiceProtocol
    private let diagnostics = FoundationModelsRuntimeDiagnostics.shared

    init(entitlementService: EntitlementServiceProtocol) {
        self.entitlementService = entitlementService
    }

    func parse(input: String, context: WorkoutCommandContext) async -> WorkoutCommandExecutionPlan {
        await diagnostics.recordAttempt(input: input)

        let aiParsingEnabledForAllUsers = true
        if !aiParsingEnabledForAllUsers && !entitlementService.canUse(.aiCommandParsing) {
            let plan = proGatePlan(input: input)
            await diagnostics.recordResult(path: "gated", outcome: "requires_pro", reason: "AI parsing requires Pro")
            return plan
        }

#if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) else {
            let reason = "Foundation Models require iOS 26+"
            let plan = unavailablePlan(input: input, reason: reason)
            await diagnostics.recordResult(path: "foundation-models", outcome: "unavailable", reason: reason)
            return plan
        }

        let plan = await parseWithFoundationModels(input: input, context: context)
        await recordDiagnostics(for: plan)
        return plan
#else
        let reason = "FoundationModels framework unavailable"
        let plan = unavailablePlan(input: input, reason: reason)
        await diagnostics.recordResult(path: "foundation-models", outcome: "unavailable", reason: reason)
        return plan
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

private extension FoundationModelsWorkoutCommandParser {
    func recordDiagnostics(for plan: WorkoutCommandExecutionPlan) async {
        switch plan.validationResult {
        case .valid:
            await diagnostics.recordResult(
                path: "foundation-models",
                outcome: "valid",
                reason: plan.metadata.userVisibleSummary
            )
        case .invalid(let reason):
            await diagnostics.recordResult(path: "foundation-models", outcome: "invalid", reason: reason)
        case .requiresConfirmation(let request):
            await diagnostics.recordResult(path: "foundation-models", outcome: "confirmation", reason: request.prompt)
        case .requiresProFeature(let feature):
            await diagnostics.recordResult(path: "foundation-models", outcome: "requires_pro", reason: feature.displayName)
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "Structured intent for workout logging commands")
private struct FMGeneratedCommand {
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

private struct FMJSONPayload: Decodable {
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
            You are a workout-command parser.
            Understand Spanish, English, and mixed-language text.
            Return only structured command intent, never explanations.

            Valid intents:
            - add_exercise
            - add_set
            - add_multiple_sets
            - duplicate_set
            - delete_set
            - unknown

            Target values:
            - current_workout
            - exercise_name
            - last_touched_set
            - last_touched_exercise
            - previous_exercise
            - selected_exercise

            Notes:
            - For bodyweight, set unit=bodyweight and weight=0.
            - If command is ambiguous, set intent=unknown.
            - Keep confidence within 0...1.
            """
        )

        do {
            let response = try await session.respond(
                to: buildPrompt(input: input, context: context),
                generating: FMGeneratedCommand.self
            )
            return mapGenerated(response.content, rawInput: input, preferredUnit: context.preferredWeightUnit)
        } catch let generationError as LanguageModelSession.GenerationError {
            switch generationError {
            case .unsupportedLanguageOrLocale(let generationContext):
                // Retry once using plain JSON text response (less constrained than Generable decoding).
                if let retried = await retryWithPlainJSON(model: model, input: input, context: context) {
                    return retried
                }
                let supported = supportedLanguagesPreview(model)
                let reason = "unsupportedLanguageOrLocale: \(generationContext.debugDescription). Supported languages: \(supported)."
                return invalidPlan(input: input, reason: reason)
            default:
                if let retried = await retryWithPlainJSON(model: model, input: input, context: context) {
                    return retried
                }
                return invalidPlan(input: input, reason: generationError.localizedDescription)
            }
        } catch {
            if let retried = await retryWithPlainJSON(model: model, input: input, context: context) {
                return retried
            }
            return invalidPlan(input: input, reason: error.localizedDescription)
        }
    }

    func supportedLanguagesPreview(_ model: SystemLanguageModel) -> String {
        let langs = model.supportedLanguages
            .map { String(describing: $0) }
            .sorted()
        guard !langs.isEmpty else { return "none" }
        let head = langs.prefix(8).joined(separator: ", ")
        return langs.count > 8 ? "\(head), ..." : head
    }

    func retryWithPlainJSON(
        model: SystemLanguageModel,
        input: String,
        context: WorkoutCommandContext
    ) async -> WorkoutCommandExecutionPlan? {
        let session = LanguageModelSession(
            model: model,
            instructions: """
            Parse workout commands and answer ONLY a JSON object.
            Allowed intents: add_exercise, add_set, add_multiple_sets, duplicate_set, delete_set, unknown.
            """
        )

        do {
            let response = try await session.respond(to: buildJSONFallbackPrompt(input: input, context: context))
            guard let payload = decodeJSONPayload(from: response.content) else { return nil }
            return mapJSONPayload(payload, rawInput: input, preferredUnit: context.preferredWeightUnit)
        } catch {
            return nil
        }
    }

    func buildJSONFallbackPrompt(input: String, context: WorkoutCommandContext) -> String {
        """
        User command: \(input)
        Preferred unit: \(context.preferredWeightUnit)
        Return JSON with keys:
        intent,target,exerciseName,equipment,sets,reps,weight,unit,weightDelta,repsDelta,confidence,summary
        """
    }

    func decodeJSONPayload(from raw: String) -> FMJSONPayload? {
        var cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleaned.hasPrefix("{"),
           let firstBrace = cleaned.firstIndex(of: "{"),
           let lastBrace = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[firstBrace...lastBrace])
        }

        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(FMJSONPayload.self, from: data)
    }

    func mapJSONPayload(_ payload: FMJSONPayload, rawInput: String, preferredUnit: String) -> WorkoutCommandExecutionPlan {
        mapGenerated(
            FMGeneratedCommand(
                intent: payload.intent,
                target: payload.target,
                exerciseName: payload.exerciseName,
                equipment: payload.equipment,
                sets: payload.sets,
                reps: payload.reps,
                weight: payload.weight,
                unit: payload.unit,
                weightDelta: payload.weightDelta,
                repsDelta: payload.repsDelta,
                confidence: payload.confidence,
                summary: payload.summary
            ),
            rawInput: rawInput,
            preferredUnit: preferredUnit
        )
    }

    func buildPrompt(input: String, context: WorkoutCommandContext) -> String {
        """
        User command: \(input)

        Context:
        - dayKey: \(context.dayKey)
        - preferredWeightUnit: \(context.preferredWeightUnit)
        - selectedWorkoutSessionID: \(context.selectedWorkoutSessionID?.uuidString ?? "none")
        - lastTouchedExerciseID: \(context.lastTouchedExerciseID?.uuidString ?? "none")
        - lastTouchedSetID: \(context.lastTouchedSetID?.uuidString ?? "none")

        Examples:
        - "curl bayesian 8 reps 25kg polea" -> add_set + exercise_name
        - "press banca 3x8 60kg" -> add_multiple_sets + sets=3 + reps=8 + weight=60
        - "otra igual" -> duplicate_set + last_touched_set
        - "borra la ultima serie" -> delete_set + last_touched_set
        """
    }

    func mapGenerated(_ payload: FMGeneratedCommand, rawInput: String, preferredUnit: String) -> WorkoutCommandExecutionPlan {
        let confidence = max(0, min(1, payload.confidence ?? 0.82))
        let summary = payload.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata = ParsedCommandMetadata(
            confidence: confidence,
            source: .foundationModels,
            needsConfirmation: confidence < 0.65,
            userVisibleSummary: (summary?.isEmpty == false ? summary! : "Interpreted command")
        )

        switch payload.intent.lowercased() {
        case "add_exercise":
            guard let name = payload.exerciseName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                return invalidPlan(input: rawInput, reason: "Missing exercise name")
            }

            let initialSet: ParsedSet?
            if payload.reps != nil || payload.weight != nil {
                let unit = payload.unit?.isEmpty == false ? payload.unit! : preferredUnit
                initialSet = ParsedSet(
                    reps: payload.reps,
                    weight: payload.weight,
                    unit: payload.unit == "bodyweight" ? "bodyweight" : unit,
                    notes: payload.equipment
                )
            } else {
                initialSet = nil
            }

            let command = ParsedWorkoutCommand.addExercise(
                AddExerciseCommand(name: name, target: .currentWorkout, initialSet: initialSet, metadata: metadata)
            )
            return validPlan(command: command, metadata: metadata)

        case "add_set":
            let unit = payload.unit?.isEmpty == false ? payload.unit! : preferredUnit
            let parsedSet = ParsedSet(
                reps: payload.reps,
                weight: payload.weight,
                unit: payload.unit == "bodyweight" ? "bodyweight" : unit,
                notes: payload.equipment
            )
            let target = parseTarget(
                raw: payload.target,
                exerciseName: payload.exerciseName,
                defaultTarget: .lastTouchedExercise
            )
            let command = ParsedWorkoutCommand.addSet(
                AddSetCommand(target: target, set: parsedSet, metadata: metadata)
            )
            return validPlan(command: command, metadata: metadata)

        case "add_multiple_sets":
            let count = max(2, payload.sets ?? 2)
            let unit = payload.unit?.isEmpty == false ? payload.unit! : preferredUnit
            let set = ParsedSet(
                reps: payload.reps,
                weight: payload.weight,
                unit: payload.unit == "bodyweight" ? "bodyweight" : unit,
                notes: payload.equipment
            )
            let target = parseTarget(
                raw: payload.target,
                exerciseName: payload.exerciseName,
                defaultTarget: .lastTouchedExercise
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
            let target = parseTarget(
                raw: payload.target,
                exerciseName: payload.exerciseName,
                defaultTarget: .lastTouchedSet
            )
            let command = ParsedWorkoutCommand.duplicateSet(
                DuplicateSetCommand(target: target, modifier: modifier, metadata: metadata)
            )
            return validPlan(command: command, metadata: metadata)

        case "delete_set":
            let target = parseTarget(
                raw: payload.target,
                exerciseName: payload.exerciseName,
                defaultTarget: .lastTouchedSet
            )
            let command = ParsedWorkoutCommand.deleteSet(
                DeleteSetCommand(target: target, metadata: metadata)
            )
            return validPlan(command: command, metadata: metadata)

        default:
            return invalidPlan(input: rawInput, reason: "Unknown intent \(payload.intent)")
        }
    }

    func parseTarget(raw: String?, exerciseName: String?, defaultTarget: WorkoutCommandTarget) -> WorkoutCommandTarget {
        guard let raw = raw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            if let exerciseName, !exerciseName.isEmpty {
                return .exerciseName(exerciseName)
            }
            return defaultTarget
        }

        switch raw {
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
            return defaultTarget
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
