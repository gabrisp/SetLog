import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Uses Apple Foundation Models when available at runtime (iOS 26+).
// Returns structured ParsedWorkoutCommand only — never prose, never mutates persistence.
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
@Generable(description: "Structured intent extracted from a gym workout command")
private struct FMGeneratedCommand {
    /// One of: add_exercise | add_set | add_multiple_sets | duplicate_set | delete_set | ask_question | unknown
    var intent: String
    /// Full multi-word exercise name exactly as the user described it (e.g. "curl en polea baja con barra")
    var exerciseName: String?
    /// Number of sets (from NxM notation or "3 series")
    var sets: Int?
    /// Reps per set
    var reps: Int?
    /// Weight value — null if user didn't mention it or said they don't know
    var weight: Double?
    /// Unit: kg | lb | bodyweight — null if not specified
    var unit: String?
    /// Target: last_touched_exercise | last_touched_set | exercise_name | previous_exercise | selected_exercise
    var target: String?
    /// When intent=ask_question: the question to show the user (e.g. "¿A qué ejercicio te refieres?")
    var clarificationQuestion: String?
    /// When intent=ask_question: 2–4 suggested answer options for the user to pick from
    var clarificationOptions: [String]?
    /// Confidence 0.0–1.0
    var confidence: Double?
}

private struct FMJSONPayload: Decodable {
    var intent: String
    var exerciseName: String?
    var sets: Int?
    var reps: Int?
    var weight: Double?
    var unit: String?
    var target: String?
    var clarificationQuestion: String?
    var clarificationOptions: [String]?
    var confidence: Double?
}

@available(iOS 26.0, *)
private extension FoundationModelsWorkoutCommandParser {

    // Cached session — not recreated per call.
    // Nonisolated lazy stored properties aren't available; use a class-level actor-isolated cache via a wrapper.
    func makeSession(model: SystemLanguageModel) -> LanguageModelSession {
        LanguageModelSession(
            model: model,
            instructions: Self.systemInstructions
        )
    }

    static let systemInstructions: String = """
    You parse gym workout commands written in Spanish, English, or a mix of both.
    Return ONLY structured data. Never explain. Never add text outside the fields.

    ── NOTATION ──────────────────────────────────────────────
    AxB        → sets=A, reps=B            ("3x8" → sets=3, reps=8)
    AxBxC      → sets=A, reps=B, weight=C  ("3x12x25" → sets=3, reps=12, weight=25)
    "25kg"     → weight=25, unit=kg
    "25lb"     → weight=25, unit=lb
    N reps/rep/repeticiones  → reps=N
    N series/serie/sets/set  → sets=N

    ── INTENTS (priority order) ──────────────────────────────
    delete_set        — "borra/elimina/quita/borra esa/delete/remove" + set reference
    duplicate_set     — "otra igual/same/duplicate/duplica/una más/repite/one more"
    add_multiple_sets — exercise + sets>1, NxM, or explicit "N series"
    add_set           — exercise + reps or weight (sets=1 implied); or bare numbers targeting last exercise
    add_exercise      — exercise name only, no numbers
    ask_question      — you know the general intent but need one critical detail
                        (ambiguous exercise name, multiple possible targets)
    unknown           — completely unclear, cannot guess

    ── WEIGHT RULES ──────────────────────────────────────────
    • Set weight to the value the user mentioned.
    • If user says "no sé el peso / sin peso / no weight / don't know / no recuerdo":
      set weight=null — still create the exercise or set.
    • Never invent a weight the user did not provide.
    • Bodyweight exercises (dominadas, fondos, pull-ups, dips): unit=bodyweight, weight=null.

    ── EXERCISE NAME ─────────────────────────────────────────
    • Capture ALL words that belong to the exercise name, including prepositions and equipment.
    • "curl en polea baja con barra"  → one exercise name (NOT "curl" + equipment)
    • "press de banca inclinado con mancuernas" → one exercise name
    • Past tense ("hice / hicimos / did / I did") means the same as present intent.
    • Equipment words ("polea", "mancuernas", "barra", "máquina") are part of the name.

    ── ask_question RULES ────────────────────────────────────
    • Use ask_question when you understand the intent (add_set, etc.) but the exercise
      name is ambiguous and context has multiple candidates.
    • clarificationQuestion: short, direct Spanish question. E.g. "¿Cuál press?" or
      "¿A qué ejercicio te refieres?"
    • clarificationOptions: 2–4 concrete candidates from the exercises listed in context.
    • Do NOT use ask_question just because weight or reps are missing — create the
      exercise/set anyway with null weight/reps.

    ── TARGET VALUES ─────────────────────────────────────────
    last_touched_exercise  (default for add_set / add_multiple_sets with no name)
    last_touched_set       (default for duplicate_set / delete_set)
    exercise_name          (when exerciseName field is filled)
    previous_exercise
    selected_exercise

    ── EXAMPLES ──────────────────────────────────────────────
    "curl bayesiano 8 reps 25kg"
      → add_set, exerciseName="curl bayesiano", reps=8, weight=25, unit=kg

    "curl en polea baja con barra 3x8 25kg"
      → add_multiple_sets, exerciseName="curl en polea baja con barra", sets=3, reps=8, weight=25, unit=kg

    "3x12x25"
      → add_multiple_sets, target=last_touched_exercise, sets=3, reps=12, weight=25

    "press banca 80kg"
      → add_set, exerciseName="press banca", weight=80, unit=kg

    "press de banca inclinado con mancuernas 3 series de 10 con 20kg"
      → add_multiple_sets, exerciseName="press de banca inclinado con mancuernas", sets=3, reps=10, weight=20, unit=kg

    "sentadilla 5 100"
      → add_set, exerciseName="sentadilla", reps=5, weight=100

    "hice 3 series de sentadilla a 100kg"
      → add_multiple_sets, exerciseName="sentadilla", sets=3, weight=100, unit=kg

    "dominadas"
      → add_exercise, exerciseName="dominadas", unit=bodyweight

    "fondos 3x10"
      → add_multiple_sets, exerciseName="fondos", sets=3, reps=10, unit=bodyweight

    "pull-ups 3x8"
      → add_multiple_sets, exerciseName="pull-ups", sets=3, reps=8, unit=bodyweight

    "otra igual"
      → duplicate_set, target=last_touched_set

    "una más"
      → duplicate_set, target=last_touched_set

    "repite"
      → duplicate_set, target=last_touched_set

    "same again"
      → duplicate_set, target=last_touched_set

    "una más pero con 5kg menos"
      → duplicate_set, target=last_touched_set, weight=-5 (pass as weightDelta context)

    "borra la última"
      → delete_set, target=last_touched_set

    "elimina esa serie"
      → delete_set, target=last_touched_set

    "quita la de antes"
      → delete_set, target=last_touched_set

    "delete last set"
      → delete_set, target=last_touched_set

    "hammer curls no recuerdo el peso"
      → add_set, exerciseName="hammer curls", weight=null

    "curl sin peso"
      → add_set, exerciseName="curl", weight=null

    "press militar"
      → add_exercise, exerciseName="press militar"

    "remo con barra en prono 4x8 60"
      → add_multiple_sets, exerciseName="remo con barra en prono", sets=4, reps=8, weight=60

    "8 reps"
      → add_set, target=last_touched_exercise, reps=8

    "25kg"
      → add_set, target=last_touched_exercise, weight=25

    "series de 8"
      → add_set, target=last_touched_exercise, reps=8

    "agrega press banca"
      → add_exercise, exerciseName="press banca"

    "añade curl con mancuernas"
      → add_exercise, exerciseName="curl con mancuernas"

    "quiero hacer sentadilla"
      → add_exercise, exerciseName="sentadilla"

    "me toca press"
      → add_exercise, exerciseName="press"

    "haz 4 series de curl"
      → add_multiple_sets, exerciseName="curl", sets=4

    "3 series"
      → add_multiple_sets, target=last_touched_exercise, sets=3

    "dos series más"
      → add_multiple_sets, target=last_touched_exercise, sets=2

    "leg press 4x10 120kg"
      → add_multiple_sets, exerciseName="leg press", sets=4, reps=10, weight=120, unit=kg

    "deadlift 5x5 100kg"
      → add_multiple_sets, exerciseName="deadlift", sets=5, reps=5, weight=100, unit=kg

    "hip thrust 3x12 80"
      → add_multiple_sets, exerciseName="hip thrust", sets=3, reps=12, weight=80

    "vuelo lateral 3x15 10kg"
      → add_multiple_sets, exerciseName="vuelo lateral", sets=3, reps=15, weight=10, unit=kg

    "extensión de cuádriceps 4x12 50kg"
      → add_multiple_sets, exerciseName="extensión de cuádriceps", sets=4, reps=12, weight=50, unit=kg

    "curl femoral tumbado 3x10 40"
      → add_multiple_sets, exerciseName="curl femoral tumbado", sets=3, reps=10, weight=40

    "jalón al pecho agarre cerrado 4x8 55kg"
      → add_multiple_sets, exerciseName="jalón al pecho agarre cerrado", sets=4, reps=8, weight=55, unit=kg

    "press"
      → ask_question, clarificationQuestion="¿Cuál press?", clarificationOptions=["Press de banca","Press militar","Press inclinado","Press con mancuernas"]

    "el curl ese"
      → ask_question, clarificationQuestion="¿A qué ejercicio te refieres?", clarificationOptions derived from context exercises
    """

    func parseWithFoundationModels(input: String, context: WorkoutCommandContext) async -> WorkoutCommandExecutionPlan {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            return unavailablePlan(input: input, reason: "On-device model is not available")
        }

        let session = makeSession(model: model)

        do {
            let response = try await session.respond(
                to: buildPrompt(input: input, context: context),
                generating: FMGeneratedCommand.self
            )
            return mapGenerated(response.content, rawInput: input, preferredUnit: context.preferredWeightUnit)
        } catch let generationError as LanguageModelSession.GenerationError {
            switch generationError {
            case .unsupportedLanguageOrLocale:
                if let retried = await retryWithPlainJSON(model: model, input: input, context: context) {
                    return retried
                }
                return invalidPlan(input: input, reason: "Unsupported language for on-device model")
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

    func retryWithPlainJSON(
        model: SystemLanguageModel,
        input: String,
        context: WorkoutCommandContext
    ) async -> WorkoutCommandExecutionPlan? {
        let session = LanguageModelSession(
            model: model,
            instructions: "Parse workout commands. Return ONLY a JSON object with keys: intent, exerciseName, sets, reps, weight, unit, target, clarificationQuestion, clarificationOptions, confidence. Allowed intents: add_exercise, add_set, add_multiple_sets, duplicate_set, delete_set, ask_question, unknown."
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
        "User command: \(input)\nPreferred unit: \(context.preferredWeightUnit)\nReturn JSON."
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
                exerciseName: payload.exerciseName,
                sets: payload.sets,
                reps: payload.reps,
                weight: payload.weight,
                unit: payload.unit,
                target: payload.target,
                clarificationQuestion: payload.clarificationQuestion,
                clarificationOptions: payload.clarificationOptions,
                confidence: payload.confidence
            ),
            rawInput: rawInput,
            preferredUnit: preferredUnit
        )
    }

    func buildPrompt(input: String, context: WorkoutCommandContext) -> String {
        var lines: [String] = []
        lines.append("User command: \(input)")
        lines.append("Preferred unit: \(context.preferredWeightUnit)")

        if let lastExerciseID = context.lastTouchedExerciseID,
           let exercise = context.exercisesInCurrentSession.first(where: { $0.id == lastExerciseID }) {
            lines.append("Last touched exercise: \(exercise.name)")
        }

        if !context.exercisesInCurrentSession.isEmpty {
            let names = context.exercisesInCurrentSession.prefix(10).map { $0.name }.joined(separator: ", ")
            lines.append("Exercises in current session: \(names)")
        }

        return lines.joined(separator: "\n")
    }

    func mapGenerated(_ payload: FMGeneratedCommand, rawInput: String, preferredUnit: String) -> WorkoutCommandExecutionPlan {
        let confidence = max(0, min(1, payload.confidence ?? 0.82))
        let metadata = ParsedCommandMetadata(
            confidence: confidence,
            source: .foundationModels,
            needsConfirmation: confidence < 0.65,
            userVisibleSummary: intentSummary(payload: payload, preferredUnit: preferredUnit)
        )

        switch payload.intent.lowercased() {

        case "add_exercise":
            guard let name = nonEmpty(payload.exerciseName) else {
                return invalidPlan(input: rawInput, reason: "Missing exercise name")
            }
            let initialSet = buildInitialSet(payload: payload, preferredUnit: preferredUnit)
            let command = ParsedWorkoutCommand.addExercise(
                AddExerciseCommand(name: name, target: .currentWorkout, initialSet: initialSet, metadata: metadata)
            )
            return validPlan(command: command, metadata: metadata)

        case "add_set":
            let set = buildParsedSet(payload: payload, preferredUnit: preferredUnit)
            let target = parseTarget(raw: payload.target, exerciseName: payload.exerciseName, defaultTarget: .lastTouchedExercise)
            let command = ParsedWorkoutCommand.addSet(AddSetCommand(target: target, set: set, metadata: metadata))
            return validPlan(command: command, metadata: metadata)

        case "add_multiple_sets":
            let count = max(2, payload.sets ?? 2)
            let set = buildParsedSet(payload: payload, preferredUnit: preferredUnit)
            let target = parseTarget(raw: payload.target, exerciseName: payload.exerciseName, defaultTarget: .lastTouchedExercise)
            let command = ParsedWorkoutCommand.addMultipleSets(
                AddMultipleSetsCommand(target: target, sets: Array(repeating: set, count: count), metadata: metadata)
            )
            return validPlan(command: command, metadata: metadata)

        case "duplicate_set":
            let target = parseTarget(raw: payload.target, exerciseName: payload.exerciseName, defaultTarget: .lastTouchedSet)
            let command = ParsedWorkoutCommand.duplicateSet(
                DuplicateSetCommand(target: target, modifier: nil, metadata: metadata)
            )
            return validPlan(command: command, metadata: metadata)

        case "delete_set":
            let target = parseTarget(raw: payload.target, exerciseName: payload.exerciseName, defaultTarget: .lastTouchedSet)
            let command = ParsedWorkoutCommand.deleteSet(DeleteSetCommand(target: target, metadata: metadata))
            return validPlan(command: command, metadata: metadata)

        case "ask_question":
            let question = payload.clarificationQuestion ?? "¿Qué querías hacer exactamente?"
            let options = payload.clarificationOptions ?? []
            let choices = options.map { option -> CommandConfirmationChoice in
                // Each option is a plain label — the user picks one and it becomes a new raw command
                CommandConfirmationChoice(
                    label: option,
                    command: .unknown(rawText: option)
                )
            }
            let request = CommandConfirmationRequest(
                prompt: question,
                choices: choices,
                rawText: rawInput,
                generatedQuestion: question
            )
            return WorkoutCommandExecutionPlan(
                command: .askForConfirmation(request),
                validationResult: .requiresConfirmation(request: request),
                metadata: ParsedCommandMetadata(
                    confidence: confidence,
                    source: .foundationModels,
                    needsConfirmation: true,
                    userVisibleSummary: question
                )
            )

        default:
            return invalidPlan(input: rawInput, reason: "Unknown intent: \(payload.intent)")
        }
    }

    func buildParsedSet(payload: FMGeneratedCommand, preferredUnit: String) -> ParsedSet {
        let unit: String?
        if payload.unit == "bodyweight" {
            unit = "bodyweight"
        } else if let u = payload.unit, !u.isEmpty {
            unit = u
        } else {
            unit = preferredUnit
        }
        return ParsedSet(reps: payload.reps, weight: payload.weight, unit: unit)
    }

    func buildInitialSet(payload: FMGeneratedCommand, preferredUnit: String) -> ParsedSet? {
        guard payload.reps != nil || payload.weight != nil else { return nil }
        return buildParsedSet(payload: payload, preferredUnit: preferredUnit)
    }

    func parseTarget(raw: String?, exerciseName: String?, defaultTarget: WorkoutCommandTarget) -> WorkoutCommandTarget {
        if let name = nonEmpty(exerciseName), raw?.lowercased() == "exercise_name" || raw == nil {
            return .exerciseName(name)
        }
        switch raw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "current_workout":        return .currentWorkout
        case "exercise_name":          return nonEmpty(exerciseName).map { .exerciseName($0) } ?? defaultTarget
        case "last_touched_set":       return .lastTouchedSet
        case "last_touched_exercise":  return .lastTouchedExercise
        case "previous_exercise":      return .previousExercise
        case "selected_exercise":      return .selectedExercise
        default:                       return defaultTarget
        }
    }

    func intentSummary(payload: FMGeneratedCommand, preferredUnit: String) -> String {
        let name = payload.exerciseName ?? "exercise"
        switch payload.intent.lowercased() {
        case "add_exercise":       return "Add exercise: \(name)"
        case "add_set":            return "Add set to \(name)"
        case "add_multiple_sets":  return "Add \(payload.sets ?? 2) sets to \(name)"
        case "duplicate_set":      return "Duplicate last set"
        case "delete_set":         return "Delete last set"
        case "ask_question":       return payload.clarificationQuestion ?? "Needs clarification"
        default:                   return "Unknown command"
        }
    }

    func nonEmpty(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
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

    func supportedLanguagesPreview(_ model: SystemLanguageModel) -> String {
        let langs = model.supportedLanguages.map { String(describing: $0) }.sorted()
        guard !langs.isEmpty else { return "none" }
        let head = langs.prefix(8).joined(separator: ", ")
        return langs.count > 8 ? "\(head), ..." : head
    }
}
#endif
