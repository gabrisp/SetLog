import Foundation

/// Dummy data for UI-only development.
/// Mirrors real DTO shapes so UI sheets can bind now and swap to live repositories later.
enum Examples {

    static let now = Date()
    static let dayKey = "2026-05-05"

    // MARK: - Day

    static let day = WorkoutDayDTO(
        id: UUID(uuidString: "A1111111-1111-1111-1111-111111111111")!,
        dayKey: dayKey,
        date: now,
        createdAt: now.addingTimeInterval(-8_000),
        updatedAt: now.addingTimeInterval(-100)
    )

    // MARK: - Sessions

    static let strengthSessionID = UUID(uuidString: "B1111111-1111-1111-1111-111111111111")!
    static let stepsSessionID = UUID(uuidString: "C1111111-1111-1111-1111-111111111111")!

    static let sessions: [WorkoutSessionDTO] = [
        WorkoutSessionDTO(
            id: strengthSessionID,
            dayKey: dayKey,
            title: "Back",
            type: "strength",
            orderIndex: 0,
            startedAt: now.addingTimeInterval(-3_600),
            endedAt: nil,
            notes: "Pull day focus",
            createdAt: now.addingTimeInterval(-4_000),
            updatedAt: now.addingTimeInterval(-60)
        ),
        WorkoutSessionDTO(
            id: stepsSessionID,
            dayKey: dayKey,
            title: "Steps",
            type: "steps",
            orderIndex: 1,
            startedAt: nil,
            endedAt: nil,
            notes: nil,
            createdAt: now.addingTimeInterval(-2_000),
            updatedAt: now.addingTimeInterval(-40)
        )
    ]

    // MARK: - Exercises

    static let latPulldownID = UUID(uuidString: "D1111111-1111-1111-1111-111111111111")!
    static let seatedRowID = UUID(uuidString: "E1111111-1111-1111-1111-111111111111")!
    static let inclineCurlID = UUID(uuidString: "F1111111-1111-1111-1111-111111111111")!
    static let walkingID = UUID(uuidString: "A2222222-2222-2222-2222-222222222222")!

    static let exercises: [ExerciseEntryDTO] = [
        ExerciseEntryDTO(
            id: latPulldownID,
            workoutSessionID: strengthSessionID,
            savedExerciseID: UUID(uuidString: "B2222222-2222-2222-2222-222222222222"),
            name: "Lat Pulldown",
            normalizedName: "lat pulldown",
            equipment: "Cable",
            primaryMusclesText: "lats, middle back",
            secondaryMusclesText: "biceps",
            isUnilateral: false,
            orderIndex: 0,
            notes: nil,
            createdAt: now.addingTimeInterval(-3_500),
            updatedAt: now.addingTimeInterval(-200)
        ),
        ExerciseEntryDTO(
            id: seatedRowID,
            workoutSessionID: strengthSessionID,
            savedExerciseID: UUID(uuidString: "C2222222-2222-2222-2222-222222222222"),
            name: "Seated Row",
            normalizedName: "seated row",
            equipment: "Machine",
            primaryMusclesText: "middle back",
            secondaryMusclesText: "rear delts",
            isUnilateral: false,
            orderIndex: 1,
            notes: "Pause 1s",
            createdAt: now.addingTimeInterval(-3_200),
            updatedAt: now.addingTimeInterval(-180)
        ),
        ExerciseEntryDTO(
            id: inclineCurlID,
            workoutSessionID: strengthSessionID,
            savedExerciseID: UUID(uuidString: "D2222222-2222-2222-2222-222222222222"),
            name: "Incline Curl",
            normalizedName: "incline curl",
            equipment: "Dumbbell",
            primaryMusclesText: "biceps",
            secondaryMusclesText: "forearms",
            isUnilateral: true,
            orderIndex: 2,
            notes: "Full stretch",
            createdAt: now.addingTimeInterval(-3_000),
            updatedAt: now.addingTimeInterval(-150)
        ),
        ExerciseEntryDTO(
            id: walkingID,
            workoutSessionID: stepsSessionID,
            savedExerciseID: nil,
            name: "Walking",
            normalizedName: "walking",
            equipment: nil,
            primaryMusclesText: "calves, glutes",
            secondaryMusclesText: nil,
            isUnilateral: false,
            orderIndex: 0,
            notes: "Outdoor",
            createdAt: now.addingTimeInterval(-1_000),
            updatedAt: now.addingTimeInterval(-120)
        )
    ]

    // MARK: - Sets

    static let inclineCurlTemplatePayload = ExerciseTemplatePayload(
        name: "Incline Curl",
        equipment: "Dumbbell",
        isUnilateral: true,
        primaryMusclesText: "biceps",
        secondaryMusclesText: "forearms",
        sets: [
            ExerciseTemplateSetPayload(
                reps: 12,
                weight: 10,
                unit: "kg",
                side: "left",
                notes: nil,
                isWarmup: false,
                isFailure: false,
                durationSeconds: nil
            ),
            ExerciseTemplateSetPayload(
                reps: 12,
                weight: 10,
                unit: "kg",
                side: "right",
                notes: nil,
                isWarmup: false,
                isFailure: false,
                durationSeconds: nil
            )
        ]
    )

    static let seatedRowTemplatePayload = ExerciseTemplatePayload(
        name: "Seated Row",
        equipment: "Machine",
        isUnilateral: false,
        primaryMusclesText: "middle back",
        secondaryMusclesText: "rear delts",
        sets: []
    )

    static let sets: [WorkoutSetDTO] = [
        WorkoutSetDTO(
            id: UUID(uuidString: "E2222222-2222-2222-2222-222222222222")!,
            exerciseEntryID: latPulldownID,
            reps: 12,
            weight: 45,
            unit: "kg",
            rpe: 7.5,
            rir: 2,
            durationSeconds: 0,
            distanceMeters: 0,
            isWarmup: true,
            isFailure: false,
            side: nil,
            orderIndex: 0,
            notes: "Warmup",
            createdAt: now.addingTimeInterval(-3_400),
            updatedAt: now.addingTimeInterval(-3_400)
        ),
        WorkoutSetDTO(
            id: UUID(uuidString: "F2222222-2222-2222-2222-222222222222")!,
            exerciseEntryID: latPulldownID,
            reps: 10,
            weight: 60,
            unit: "kg",
            rpe: 8,
            rir: 1,
            durationSeconds: 0,
            distanceMeters: 0,
            isWarmup: false,
            isFailure: false,
            side: nil,
            orderIndex: 1,
            notes: nil,
            createdAt: now.addingTimeInterval(-3_300),
            updatedAt: now.addingTimeInterval(-3_300)
        ),
        WorkoutSetDTO(
            id: UUID(uuidString: "A3333333-3333-3333-3333-333333333333")!,
            exerciseEntryID: seatedRowID,
            reps: 12,
            weight: 52.5,
            unit: "kg",
            rpe: 8,
            rir: 1,
            durationSeconds: 0,
            distanceMeters: 0,
            isWarmup: false,
            isFailure: false,
            side: nil,
            orderIndex: 0,
            notes: "Controlled tempo",
            createdAt: now.addingTimeInterval(-3_100),
            updatedAt: now.addingTimeInterval(-3_100)
        ),
        WorkoutSetDTO(
            id: UUID(uuidString: "B3333333-3333-3333-3333-333333333333")!,
            exerciseEntryID: inclineCurlID,
            reps: 12,
            weight: 12,
            unit: "kg",
            rpe: 8.5,
            rir: 1,
            durationSeconds: 0,
            distanceMeters: 0,
            isWarmup: false,
            isFailure: false,
            side: "left",
            orderIndex: 0,
            notes: nil,
            createdAt: now.addingTimeInterval(-2_800),
            updatedAt: now.addingTimeInterval(-2_800)
        ),
        WorkoutSetDTO(
            id: UUID(uuidString: "C3333333-3333-3333-3333-333333333333")!,
            exerciseEntryID: inclineCurlID,
            reps: 12,
            weight: 12,
            unit: "kg",
            rpe: 8.5,
            rir: 1,
            durationSeconds: 0,
            distanceMeters: 0,
            isWarmup: false,
            isFailure: false,
            side: "right",
            orderIndex: 1,
            notes: nil,
            createdAt: now.addingTimeInterval(-2_700),
            updatedAt: now.addingTimeInterval(-2_700)
        ),
        WorkoutSetDTO(
            id: UUID(uuidString: "D3333333-3333-3333-3333-333333333333")!,
            exerciseEntryID: walkingID,
            reps: 0,
            weight: 0,
            unit: "bodyweight",
            rpe: 0,
            rir: 0,
            durationSeconds: 1800,
            distanceMeters: 3200,
            isWarmup: false,
            isFailure: false,
            side: nil,
            orderIndex: 0,
            notes: "30 min walk",
            createdAt: now.addingTimeInterval(-900),
            updatedAt: now.addingTimeInterval(-900)
        )
    ]

    // MARK: - Recents / Templates / Saved

    static let recents: [RecentWorkoutSnippetDTO] = [
        RecentWorkoutSnippetDTO(
            id: UUID(uuidString: "E3333333-3333-3333-3333-333333333333")!,
            title: "add one more set",
            normalizedTitle: "add one more set",
            payloadJSON: "{\"action\":\"add_sets\",\"sets_to_add\":1}",
            snippetType: "command",
            createdAt: now.addingTimeInterval(-5_000),
            lastUsedAt: now.addingTimeInterval(-1_200),
            useCount: 5,
            decayScore: 3.2,
            sourceDayKey: dayKey,
            sourceWorkoutSessionID: strengthSessionID,
            sourceExerciseEntryID: latPulldownID
        ),
        RecentWorkoutSnippetDTO(
            id: UUID(uuidString: "F3333333-3333-3333-3333-333333333333")!,
            title: "lat pulldown 3x10 60kg",
            normalizedTitle: "lat pulldown 3x10 60kg",
            payloadJSON: "{\"action\":\"add_exercise\",\"exercise\":\"Lat Pulldown\",\"sets\":3,\"reps\":10,\"weight\":60,\"unit\":\"kg\"}",
            snippetType: "command",
            createdAt: now.addingTimeInterval(-4_500),
            lastUsedAt: now.addingTimeInterval(-1_600),
            useCount: 3,
            decayScore: 2.7,
            sourceDayKey: dayKey,
            sourceWorkoutSessionID: strengthSessionID,
            sourceExerciseEntryID: latPulldownID
        )
    ]

    static let templates: [FavoriteWorkoutSnippetDTO] = [
        FavoriteWorkoutSnippetDTO(
            id: UUID(uuidString: "A4444444-4444-4444-4444-444444444444")!,
            savedExerciseID: UUID(uuidString: "D2222222-2222-2222-2222-222222222222")!,
            title: "Incline Curl template",
            payloadJSON: encodeTemplatePayload(inclineCurlTemplatePayload),
            snippetType: "exercise_template_with_sets",
            createdAt: now.addingTimeInterval(-6_000),
            updatedAt: now.addingTimeInterval(-1_200),
            lastUsedAt: now.addingTimeInterval(-1_200),
            useCount: 4
        ),
        FavoriteWorkoutSnippetDTO(
            id: UUID(uuidString: "B4444444-4444-4444-4444-444444444444")!,
            savedExerciseID: UUID(uuidString: "C2222222-2222-2222-2222-222222222222")!,
            title: "Seated Row empty template",
            payloadJSON: encodeTemplatePayload(seatedRowTemplatePayload),
            snippetType: "exercise_template_empty",
            createdAt: now.addingTimeInterval(-7_000),
            updatedAt: now.addingTimeInterval(-2_000),
            lastUsedAt: now.addingTimeInterval(-2_000),
            useCount: 2
        )
    ]

    static let saved: [SavedExerciseDTO] = [
        SavedExerciseDTO(
            id: UUID(uuidString: "B2222222-2222-2222-2222-222222222222")!,
            name: "Lat Pulldown",
            normalizedName: "lat pulldown",
            imageFileName: nil,
            primaryMusclesText: "lats",
            secondaryMusclesText: "biceps",
            aiPrimaryMusclesText: nil,
            aiSecondaryMusclesText: nil,
            equipment: "Cable",
            descriptionText: "Vertical pull",
            instructionsText: nil,
            createdAt: now.addingTimeInterval(-9_000),
            updatedAt: now.addingTimeInterval(-3_000),
            lastUsedAt: now.addingTimeInterval(-1_500),
            useCount: 10,
            isArchived: false
        ),
        SavedExerciseDTO(
            id: UUID(uuidString: "C2222222-2222-2222-2222-222222222222")!,
            name: "Seated Row",
            normalizedName: "seated row",
            imageFileName: nil,
            primaryMusclesText: "middle back",
            secondaryMusclesText: "rear delts",
            aiPrimaryMusclesText: nil,
            aiSecondaryMusclesText: nil,
            equipment: "Machine",
            descriptionText: "Horizontal pull",
            instructionsText: "Pull handle to torso, control eccentric.",
            createdAt: now.addingTimeInterval(-8_500),
            updatedAt: now.addingTimeInterval(-2_950),
            lastUsedAt: now.addingTimeInterval(-1_300),
            useCount: 8,
            isArchived: false
        ),
        SavedExerciseDTO(
            id: UUID(uuidString: "D2222222-2222-2222-2222-222222222222")!,
            name: "Incline Curl",
            normalizedName: "incline curl",
            imageFileName: nil,
            primaryMusclesText: "biceps",
            secondaryMusclesText: "forearms",
            aiPrimaryMusclesText: nil,
            aiSecondaryMusclesText: nil,
            equipment: "Dumbbell",
            descriptionText: "Biceps isolation",
            instructionsText: "Keep upper arm still and supinate at top.",
            createdAt: now.addingTimeInterval(-8_200),
            updatedAt: now.addingTimeInterval(-2_900),
            lastUsedAt: now.addingTimeInterval(-1_100),
            useCount: 7,
            isArchived: false
        ),
        SavedExerciseDTO(
            id: UUID(uuidString: "C4444444-4444-4444-4444-444444444444")!,
            name: "Walking",
            normalizedName: "walking",
            imageFileName: nil,
            primaryMusclesText: "calves",
            secondaryMusclesText: "glutes",
            aiPrimaryMusclesText: nil,
            aiSecondaryMusclesText: nil,
            equipment: nil,
            descriptionText: "Daily steps",
            instructionsText: nil,
            createdAt: now.addingTimeInterval(-8_000),
            updatedAt: now.addingTimeInterval(-2_800),
            lastUsedAt: now.addingTimeInterval(-1_000),
            useCount: 7,
            isArchived: false
        )
    ]

    // MARK: - Helpers

    static func exercises(for sessionID: UUID) -> [ExerciseEntryDTO] {
        exercises
            .filter { $0.workoutSessionID == sessionID }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    static func sets(for exerciseID: UUID) -> [WorkoutSetDTO] {
        sets
            .filter { $0.exerciseEntryID == exerciseID }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    static var exercisesBySessionID: [UUID: [ExerciseEntryDTO]] {
        Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, exercises(for: $0.id)) })
    }

    static var setsByExerciseID: [UUID: [WorkoutSetDTO]] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, sets(for: $0.id)) })
    }

    static func summary(for exerciseID: UUID) -> String {
        let exerciseSets = sets(for: exerciseID)
        guard let first = exerciseSets.first else { return "No sets yet" }
        return "\(exerciseSets.count) sets, \(first.weight.cleanWeight) \(first.unit)"
    }

    private static func encodeTemplatePayload(_ payload: ExerciseTemplatePayload) -> String {
        let encoder = JSONEncoder()
        guard
            let data = try? encoder.encode(payload),
            let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return json
    }
}

private extension Double {
    var cleanWeight: String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(self))
        }
        return String(self)
    }
}
