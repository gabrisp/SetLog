import Foundation

enum PlanType {
    case free
    case premium
}

struct WorkoutSessionContext: Codable {
    var lastExercise: String?
    var lastWeight: Double?
    var lastReps: Int?
    var lastSets: Int?
    var lastEquipment: String?

    enum CodingKeys: String, CodingKey {
        case lastExercise = "last_exercise"
        case lastWeight = "last_weight"
        case lastReps = "last_reps"
        case lastSets = "last_sets"
        case lastEquipment = "last_equipment"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let lastExercise {
            try container.encode(lastExercise, forKey: .lastExercise)
        } else {
            try container.encodeNil(forKey: .lastExercise)
        }

        if let lastWeight {
            try container.encode(lastWeight, forKey: .lastWeight)
        } else {
            try container.encodeNil(forKey: .lastWeight)
        }

        if let lastReps {
            try container.encode(lastReps, forKey: .lastReps)
        } else {
            try container.encodeNil(forKey: .lastReps)
        }

        if let lastSets {
            try container.encode(lastSets, forKey: .lastSets)
        } else {
            try container.encodeNil(forKey: .lastSets)
        }

        if let lastEquipment {
            try container.encode(lastEquipment, forKey: .lastEquipment)
        } else {
            try container.encodeNil(forKey: .lastEquipment)
        }
    }
}

enum WorkoutCommandAction: String, Codable {
    case addExercise = "add_exercise"
    case addSets = "add_sets"
    case removeLastSet = "remove_last_set"
    case modifyLastSet = "modify_last_set"
    case repeatLastExercise = "repeat_last_exercise"
}

struct WorkoutCommandResult: Codable {
    var action: WorkoutCommandAction
    var exercise: String?
    var setsToAdd: Int?
    var sets: Int?
    var reps: Int?
    var repsWasExplicitlyProvided: Bool
    var weight: Double?
    var weightDelta: Double?
    var unit: String?
    var equipment: String?
    var modifiers: [String]
    var notes: String?
    var restSeconds: Int?
    var confidence: Double

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
        case restSeconds = "rest_seconds"
        case confidence
    }

    init(
        action: WorkoutCommandAction,
        exercise: String? = nil,
        setsToAdd: Int? = nil,
        sets: Int? = nil,
        reps: Int? = nil,
        repsWasExplicitlyProvided: Bool? = nil,
        weight: Double? = nil,
        weightDelta: Double? = nil,
        unit: String? = nil,
        equipment: String? = nil,
        modifiers: [String] = [],
        notes: String? = nil,
        restSeconds: Int? = nil,
        confidence: Double
    ) {
        self.action = action
        self.exercise = exercise
        self.setsToAdd = setsToAdd
        self.sets = sets
        self.reps = reps
        self.repsWasExplicitlyProvided = repsWasExplicitlyProvided ?? (reps != nil)
        self.weight = weight
        self.weightDelta = weightDelta
        self.unit = unit
        self.equipment = equipment
        self.modifiers = modifiers
        self.notes = notes
        self.restSeconds = restSeconds
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(WorkoutCommandAction.self, forKey: .action)
        exercise = try container.decodeIfPresent(String.self, forKey: .exercise)
        setsToAdd = try container.decodeIfPresent(Int.self, forKey: .setsToAdd)
        sets = try container.decodeIfPresent(Int.self, forKey: .sets)
        repsWasExplicitlyProvided = container.contains(.reps)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        weightDelta = try container.decodeIfPresent(Double.self, forKey: .weightDelta)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        equipment = try container.decodeIfPresent(String.self, forKey: .equipment)
        modifiers = try container.decodeIfPresent([String].self, forKey: .modifiers) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds)
        confidence = try container.decode(Double.self, forKey: .confidence)
    }

    var isAddOperation: Bool {
        switch action {
        case .addExercise, .addSets:
            return true
        case .repeatLastExercise:
            return true
        case .removeLastSet, .modifyLastSet:
            return false
        }
    }
}

struct AIProviderResponse {
    var result: WorkoutCommandResult
    var inputTokens: Int?
    var outputTokens: Int?
}

struct AIUsageStatus {
    let plan: PlanType
    let exercisesRemainingToday: Int?
    let aiUsagePercentage: Double?
    let resetDescription: String
}

enum AIUsageError: LocalizedError, Equatable {
    case dailyExerciseLimitReached
    case monthlyAIUsageLimitReached
    case invalidAIResponse
    case providerFailed
    case noCurrentUser

    var errorDescription: String? {
        switch self {
        case .dailyExerciseLimitReached:
            return "You’ve reached your free daily limit of 2 exercises."
        case .monthlyAIUsageLimitReached:
            return "You’ve used your monthly AI usage."
        case .invalidAIResponse:
            return "I couldn’t understand that command. Try writing it another way."
        case .providerFailed:
            return "AI provider unavailable. Set GROQ_API_KEY in your run environment."
        case .noCurrentUser:
            return "I couldn’t identify the current user."
        }
    }
}
