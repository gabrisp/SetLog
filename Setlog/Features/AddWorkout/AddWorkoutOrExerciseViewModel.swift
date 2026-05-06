import Foundation

@MainActor
@Observable
final class AddWorkoutOrExerciseViewModel {

    let dayKey: String

    var searchText: String = ""
    var selectedMuscle: String? = nil
    var selectedEquipment: String? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    var sessions: [WorkoutSessionDTO] = []
    var selectedSessionID: UUID? = nil
    var ejerciciosBase: [EjercicioBase] = []
    var favoriteTemplates: [FavoriteWorkoutSnippetDTO] = []

    var todosLosMusculos: [String] {
        EjerciciosBaseLoader.todosLosMusculos()
    }

    var todosLosEquipment: [String] {
        EjerciciosBaseLoader.todosLosEquipamientos()
    }

    var ejerciciosBaseFiltrados: [EjercicioBase] {
        var filtrados = ejerciciosBase

        if !searchText.isEmpty {
            filtrados = filtrados.filter { ejercicio in
                ejercicio.name.localizedCaseInsensitiveContains(searchText) ||
                ejercicio.musculos.joined(separator: " ").localizedCaseInsensitiveContains(searchText) ||
                ejercicio.category.localizedCaseInsensitiveContains(searchText) ||
                ejercicio.equipment.joined(separator: " ").localizedCaseInsensitiveContains(searchText) ||
                (ejercicio.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        if let musculo = selectedMuscle {
            filtrados = filtrados.filter { ejercicio in
                ejercicio.musculos.contains { $0.localizedCaseInsensitiveCompare(musculo) == .orderedSame }
            }
        }

        if let equipment = selectedEquipment {
            filtrados = filtrados.filter { ejercicio in
                ejercicio.equipment.contains { $0.localizedCaseInsensitiveCompare(equipment) == .orderedSame }
            }
        }

        return filtrados
    }

    var filteredTemplates: [FavoriteWorkoutSnippetDTO] {
        guard !searchText.isEmpty else { return favoriteTemplates }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return favoriteTemplates.filter {
            $0.title.localizedCaseInsensitiveContains(q)
        }
    }

    private var router: AppRouter
    private var workoutRepository: WorkoutRepositoryProtocol?
    private var exerciseRepository: ExerciseRepositoryProtocol?
    private var exerciseIdentityResolver: ExerciseIdentityResolver?

    init(dayKey: String, router: AppRouter) {
        self.dayKey = dayKey
        self.router = router
    }

    func wireRouter(_ router: AppRouter) {
        self.router = router
    }

    func wireDependencies(
        workoutRepository: WorkoutRepositoryProtocol,
        exerciseRepository: ExerciseRepositoryProtocol,
        exerciseIdentityResolver: ExerciseIdentityResolver
    ) {
        self.workoutRepository = workoutRepository
        self.exerciseRepository = exerciseRepository
        self.exerciseIdentityResolver = exerciseIdentityResolver
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            guard let workoutRepository else { return }
            do {
                ejerciciosBase = EjerciciosBaseLoader.cargarEjercicios()
                let fetched = try await workoutRepository.fetchWorkoutSessions(dayKey: dayKey)
                sessions = fetched.sorted { $0.orderIndex < $1.orderIndex }
                if selectedSessionID == nil {
                    selectedSessionID = sessions.first?.id
                }

                if let exerciseRepository {
                    favoriteTemplates = try await exerciseRepository.fetchFavoriteSnippets()
                        .filter { $0.snippetType.contains("template") }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func startNewWorkoutSession() {
        guard let workoutRepository else { return }
        Task {
            do {
                let session = try await workoutRepository.createWorkoutSession(dayKey: dayKey, type: "strength", title: "Workout")
                if !sessions.contains(where: { $0.id == session.id }) {
                    sessions.append(session)
                    sessions.sort { $0.orderIndex < $1.orderIndex }
                }
                selectedSessionID = session.id
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func startStepsSession() {
        guard let workoutRepository else { return }
        Task {
            do {
                let session = try await workoutRepository.createWorkoutSession(dayKey: dayKey, type: "steps", title: "Steps")
                if !sessions.contains(where: { $0.id == session.id }) {
                    sessions.append(session)
                    sessions.sort { $0.orderIndex < $1.orderIndex }
                }
                selectedSessionID = session.id
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func addEjercicioBase(_ ejercicio: EjercicioBase) {
        Task {
            await addManualExercise(
                name: ejercicio.name,
                equipment: ejercicio.equipment.first,
                primaryMusclesText: ejercicio.primary_muscles.joined(separator: ", "),
                secondaryMusclesText: ejercicio.secondary_muscles.joined(separator: ", ")
            )
        }
    }

    func addManualExercise(name: String) {
        Task {
            await addManualExercise(
                name: name,
                equipment: nil,
                primaryMusclesText: nil,
                secondaryMusclesText: nil
            )
        }
    }

    func applyTemplate(_ template: FavoriteWorkoutSnippetDTO) {
        guard let workoutRepository else { return }

        Task {
            do {
                let targetSessionID = try await ensureTargetSessionID(workoutRepository: workoutRepository)
                let payload = try decodeTemplatePayload(from: template.payloadJSON, fallbackName: template.title)

                let added = try await workoutRepository.addExercise(
                    toWorkoutSessionID: targetSessionID,
                    name: payload.name,
                    equipment: payload.equipment,
                    savedExerciseID: template.savedExerciseID,
                    isUnilateral: payload.isUnilateral
                )

                try await workoutRepository.updateExercise(
                    id: added.id,
                    name: nil,
                    equipment: payload.equipment,
                    notes: nil,
                    isUnilateral: payload.isUnilateral,
                    primaryMusclesText: payload.primaryMusclesText,
                    secondaryMusclesText: payload.secondaryMusclesText
                )

                if !payload.sets.isEmpty {
                    for set in payload.sets {
                        _ = try await workoutRepository.addSet(
                            toExerciseEntryID: added.id,
                            reps: set.reps,
                            weight: set.weight,
                            unit: set.unit,
                            side: set.side,
                            notes: set.notes,
                            isWarmup: set.isWarmup,
                            isFailure: set.isFailure,
                            durationSeconds: set.durationSeconds
                        )
                    }
                }

                if let exerciseRepository {
                    try? await exerciseRepository.markUsed(id: template.savedExerciseID)
                }

                NotificationCenter.default.post(name: .workoutDataDidChange, object: nil)
                router.dismissSheet()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func addManualExercise(
        name: String,
        equipment: String?,
        primaryMusclesText: String?,
        secondaryMusclesText: String?
    ) async {
        guard let workoutRepository, let exerciseIdentityResolver else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        do {
            let targetSessionID = try await ensureTargetSessionID(workoutRepository: workoutRepository)
            let identity = try await exerciseIdentityResolver.resolve(
                rawInput: trimmedName,
                hintedExerciseName: trimmedName,
                hintedEquipment: equipment,
                aiPrimaryMusclesText: primaryMusclesText,
                aiSecondaryMusclesText: secondaryMusclesText
            )
            let added = try await workoutRepository.addExercise(
                toWorkoutSessionID: targetSessionID,
                name: identity.canonicalName,
                equipment: equipment ?? identity.equipment,
                savedExerciseID: identity.savedExerciseID,
                isUnilateral: false
            )

            try await workoutRepository.updateExercise(
                id: added.id,
                name: nil,
                equipment: equipment ?? identity.equipment,
                notes: nil,
                isUnilateral: nil,
                primaryMusclesText: primaryMusclesText ?? identity.primaryMusclesText,
                secondaryMusclesText: secondaryMusclesText ?? identity.secondaryMusclesText
            )

            NotificationCenter.default.post(name: .workoutDataDidChange, object: nil)
            router.dismissSheet()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func decodeTemplatePayload(from rawJSON: String, fallbackName: String) throws -> ExerciseTemplatePayload {
        guard let data = rawJSON.data(using: .utf8) else {
            throw NSError(domain: "Template", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid template data"])
        }
        do {
            return try JSONDecoder().decode(ExerciseTemplatePayload.self, from: data)
        } catch {
            // Backward compatibility: if payload is empty or invalid, create a minimal template from title.
            let cleanedName = fallbackName
                .replacingOccurrences(of: " empty template", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " template", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ExerciseTemplatePayload(
                name: cleanedName.isEmpty ? "Template Exercise" : cleanedName,
                equipment: nil,
                isUnilateral: false,
                primaryMusclesText: nil,
                secondaryMusclesText: nil,
                sets: []
            )
        }
    }

    private func ensureTargetSessionID(workoutRepository: WorkoutRepositoryProtocol) async throws -> UUID {
        if let selectedSessionID {
            return selectedSessionID
        }
        if let existing = sessions.first {
            if let strength = sessions.first(where: { $0.type.lowercased() == "strength" }) {
                selectedSessionID = strength.id
                return strength.id
            }
            selectedSessionID = existing.id
            return existing.id
        }

        let created = try await workoutRepository.createWorkoutSession(dayKey: dayKey, type: "strength", title: "Workout")
        sessions.append(created)
        sessions.sort { $0.orderIndex < $1.orderIndex }
        selectedSessionID = created.id
        return created.id
    }
}
