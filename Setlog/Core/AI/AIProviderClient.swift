import Foundation

protocol AIProviderClient {
    func interpret(command: String, context: WorkoutSessionContext) async throws -> AIProviderResponse
}

private enum AIDebugLog {
    static func enabled() -> Bool {
        true
    }

    static func print(_ message: @autoclosure () -> String) {
        guard enabled() else { return }
        Swift.print("[AI DEBUG] \(message())")
    }
}

final class GroqAIProviderClient: AIProviderClient {

    private struct ChatMessage: Encodable {
        let role: String
        let content: String
    }

    private struct ChatRequestBody: Encodable {
        let model: String
        let temperature: Double
        let messages: [ChatMessage]
        let responseFormat: ResponseFormat

        struct ResponseFormat: Encodable {
            let type: String

            enum CodingKeys: String, CodingKey {
                case type
            }
        }

        enum CodingKeys: String, CodingKey {
            case model
            case temperature
            case messages
            case responseFormat = "response_format"
        }
    }

    private struct GroqResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }

            let message: Message
        }

        struct Usage: Decodable {
            let promptTokens: Int?
            let completionTokens: Int?

            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
            }
        }

        let choices: [Choice]
        let usage: Usage?
    }

    private struct CommandPayload: Encodable {
        let sessionContext: WorkoutSessionContext
        let command: String

        enum CodingKeys: String, CodingKey {
            case sessionContext = "session_context"
            case command
        }
    }

    private struct RawWorkoutCommandResult: Decodable {
        let action: String?
        let exercise: String?
        let setsToAdd: Int?
        let sets: Int?
        let reps: Int?
        let weight: Double?
        let weightDelta: Double?
        let unit: String?
        let equipment: String?
        let modifiers: [String]?
        let notes: String?
        let confidence: Double?

        enum CodingKeys: String, CodingKey {
            case action
            case exercise
            case setsToAdd = "sets_to_add"
            case sets
            case reps
            case weight
            case weightDelta = "weight_delta"
            case unit
            case equipment
            case modifiers
            case notes
            case confidence
        }
    }

    private let session: URLSession
    private let apiKey: String

    init(session: URLSession = .shared, apiKey: String) {
        self.session = session
        self.apiKey = apiKey
    }

    func interpret(command: String, context: WorkoutSessionContext) async throws -> AIProviderResponse {
        let payload = CommandPayload(sessionContext: context, command: command)
        let payloadData = try JSONEncoder().encode(payload)
        guard let payloadJSON = String(data: payloadData, encoding: .utf8) else {
            throw AIUsageError.providerFailed
        }
        let userContent = """
        Input payload:
        \(payloadJSON)

        Return ONLY the JSON object with the required keys from the system instructions.
        """
        AIDebugLog.print("Prompt chars: \(AICommandPrompt.system.count)")
        AIDebugLog.print("User payload: \(payloadJSON)")

        let body = ChatRequestBody(
            model: "llama-3.1-8b-instant",
            temperature: 0.1,
            messages: [
                ChatMessage(role: "system", content: AICommandPrompt.system),
                ChatMessage(role: "user", content: userContent)
            ],
            responseFormat: .init(type: "json_object")
        )

        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                AIDebugLog.print("HTTP status: \(httpResponse.statusCode) body: \(bodyText)")
            }
            throw AIUsageError.providerFailed
        }

        let decoded = try JSONDecoder().decode(GroqResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AIUsageError.providerFailed
        }
        AIDebugLog.print("Raw model content: \(content)")

        let jsonString = Self.extractJSONObject(from: content)
        guard let jsonData = jsonString.data(using: .utf8) else {
            AIDebugLog.print("JSON extraction failed. Extracted: \(jsonString)")
            throw AIUsageError.invalidAIResponse
        }
        AIDebugLog.print("Extracted JSON: \(jsonString)")

        let result: WorkoutCommandResult
        do {
            let raw = try JSONDecoder().decode(RawWorkoutCommandResult.self, from: jsonData)
            result = Self.normalize(raw: raw, originalCommand: command)
        } catch {
            AIDebugLog.print("Decode error: \(error.localizedDescription)")
            throw AIUsageError.invalidAIResponse
        }

        return AIProviderResponse(
            result: result,
            inputTokens: decoded.usage?.promptTokens,
            outputTokens: decoded.usage?.completionTokens
        )
    }

    private static func extractJSONObject(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.hasPrefix("{"),
              let firstBrace = trimmed.firstIndex(of: "{"),
              let lastBrace = trimmed.lastIndex(of: "}") else {
            return trimmed
        }

        return String(trimmed[firstBrace...lastBrace])
    }

    private static func normalize(raw: RawWorkoutCommandResult, originalCommand: String) -> WorkoutCommandResult {
        let inferredAction = inferAction(from: originalCommand)
        let action = WorkoutCommandAction(rawValue: raw.action ?? "") ?? inferredAction

        let commandTrimmed = originalCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let inferredExercise = action == .addExercise ? commandTrimmed : nil
        let exercise = (raw.exercise?.isEmpty == false ? raw.exercise : nil) ?? inferredExercise

        let confidence = raw.confidence ?? 0

        let setsToAdd: Int?
        if action == .addSets {
            setsToAdd = max(1, raw.setsToAdd ?? raw.sets ?? 1)
        } else {
            setsToAdd = raw.setsToAdd
        }

        return WorkoutCommandResult(
            action: action,
            exercise: exercise,
            setsToAdd: setsToAdd,
            sets: raw.sets,
            reps: raw.reps,
            weight: raw.weight,
            weightDelta: raw.weightDelta,
            unit: raw.unit,
            equipment: raw.equipment,
            modifiers: raw.modifiers ?? [],
            notes: raw.notes,
            confidence: confidence
        )
    }

    private static func inferAction(from command: String) -> WorkoutCommandAction {
        let normalized = command
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.contains("quita la ultima serie")
            || normalized.contains("remove last set")
            || normalized.contains("delete last set") {
            return .removeLastSet
        }

        if normalized.contains("otra serie")
            || normalized.contains("another set")
            || normalized.contains("dos series")
            || normalized.contains("set mas")
            || normalized.contains("set más") {
            return .addSets
        }

        if normalized.contains("repite el ejercicio anterior")
            || normalized.contains("repeat last exercise") {
            return .repeatLastExercise
        }

        if normalized.contains("kg menos")
            || normalized.contains("sube")
            || normalized.contains("baja") {
            return .modifyLastSet
        }

        return .addExercise
    }
}

final class MockGroqAIProviderClient: AIProviderClient {

    func interpret(command: String, context: WorkoutSessionContext) async throws -> AIProviderResponse {
        let normalized = command
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let result: WorkoutCommandResult

        if normalized.contains("quita") && normalized.contains("ultima serie") {
            result = WorkoutCommandResult(action: .removeLastSet, confidence: 0.95)
        } else if normalized.contains("repite el ejercicio anterior") || normalized.contains("repeat last exercise") {
            result = WorkoutCommandResult(action: .repeatLastExercise, confidence: 0.9)
        } else if normalized.contains("otra serie") || normalized.contains("another set") || normalized.contains("dos series") {
            let setsToAdd = normalized.contains("dos") ? 2 : 1
            result = WorkoutCommandResult(action: .addSets, setsToAdd: setsToAdd, confidence: 0.9)
        } else if normalized.contains("kg menos") || normalized.contains("sube") {
            let delta = normalized.contains("menos") ? -5.0 : 2.5
            result = WorkoutCommandResult(action: .modifyLastSet, weightDelta: delta, unit: "kg", confidence: 0.85)
        } else if let parsed = parseExercisePattern(from: normalized) {
            result = WorkoutCommandResult(
                action: .addExercise,
                exercise: parsed.exercise,
                sets: parsed.sets,
                reps: parsed.reps,
                unit: "kg",
                confidence: 0.88
            )
        } else if let parsed = parseExerciseSetsWeightPattern(from: normalized) {
            result = WorkoutCommandResult(
                action: .addExercise,
                exercise: parsed.exercise,
                sets: parsed.sets,
                reps: nil,
                repsWasExplicitlyProvided: false,
                weight: parsed.weight,
                unit: parsed.unit,
                equipment: parsed.equipment,
                confidence: 0.86
            )
        } else {
            result = WorkoutCommandResult(
                action: .addExercise,
                exercise: normalized.isEmpty ? context.lastExercise : normalized,
                confidence: 0.78
            )
        }

        return AIProviderResponse(
            result: result,
            inputTokens: max(1, (command.count + 3) / 4),
            outputTokens: 60
        )
    }

    private func parseExercisePattern(from input: String) -> (exercise: String, sets: Int?, reps: Int?)? {
        let pattern = #"^(.+?)\s+(\d+)x(\d+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: input, range: NSRange(location: 0, length: input.utf16.count)),
              match.numberOfRanges == 4,
              let exerciseRange = Range(match.range(at: 1), in: input),
              let setsRange = Range(match.range(at: 2), in: input),
              let repsRange = Range(match.range(at: 3), in: input) else {
            return nil
        }

        let exercise = String(input[exerciseRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let sets = Int(input[setsRange])
        let reps = Int(input[repsRange])
        guard !exercise.isEmpty else { return nil }
        return (exercise, sets, reps)
    }

    private func parseExerciseSetsWeightPattern(from input: String) -> (exercise: String, sets: Int, weight: Double, unit: String, equipment: String?)? {
        let pattern = #"^(.+?)\s+(\d+)\s*(?:series|serie|sets?|set)\s+(\d+(?:[\.,]\d+)?)\s*(kg|lb)\b$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: input, range: NSRange(location: 0, length: input.utf16.count)),
              match.numberOfRanges == 5,
              let exerciseRange = Range(match.range(at: 1), in: input),
              let setsRange = Range(match.range(at: 2), in: input),
              let weightRange = Range(match.range(at: 3), in: input),
              let unitRange = Range(match.range(at: 4), in: input) else {
            return nil
        }

        var exercise = String(input[exerciseRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let sets = Int(input[setsRange]) ?? 1
        let weight = Double(String(input[weightRange]).replacingOccurrences(of: ",", with: ".")) ?? 0
        let unit = String(input[unitRange])

        var equipment: String? = nil
        if exercise.contains("polea") || exercise.contains("cable") {
            equipment = "cable"
        } else if exercise.contains("mancuerna") || exercise.contains("dumbbell") {
            equipment = "dumbbell"
        } else if exercise.contains("barra") || exercise.contains("barbell") {
            equipment = "barbell"
        }

        exercise = exercise
            .replacingOccurrences(of: " en polea", with: "")
            .replacingOccurrences(of: " en cable", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !exercise.isEmpty else { return nil }
        return (exercise, max(1, sets), max(0, weight), unit, equipment)
    }
}
