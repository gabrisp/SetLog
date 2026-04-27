import SwiftUI

struct CommandClarificationSheet: View {

    private enum QuestionKind {
        case intent
        case target
        case adjustment

        var title: String {
            switch self {
            case .intent: return "¿Qué querías hacer?"
            case .target: return "¿Dónde aplicarlo?"
            case .adjustment: return "¿Quieres ajustar algo?"
            }
        }
    }

    private enum TargetOption: String, CaseIterable, Identifiable {
        case lastTouchedExercise
        case previousExercise
        case selectedExercise
        case lastTouchedSet

        var id: String { rawValue }

        var label: String {
            switch self {
            case .lastTouchedExercise: return "Último ejercicio"
            case .previousExercise: return "Ejercicio anterior"
            case .selectedExercise: return "Ejercicio seleccionado"
            case .lastTouchedSet: return "Última serie"
            }
        }
    }

    private enum AdjustmentOption: String, CaseIterable, Identifiable {
        case none
        case minusTenKg
        case plusTenKg
        case minusOneRep
        case plusOneRep

        var id: String { rawValue }

        var label: String {
            switch self {
            case .none: return "Sin cambios"
            case .minusTenKg: return "-10 kg"
            case .plusTenKg: return "+10 kg"
            case .minusOneRep: return "-1 repetición"
            case .plusOneRep: return "+1 repetición"
            }
        }

        var weightDelta: Double? {
            switch self {
            case .minusTenKg: return -10
            case .plusTenKg: return 10
            default: return nil
            }
        }

        var repsDelta: Int? {
            switch self {
            case .minusOneRep: return -1
            case .plusOneRep: return 1
            default: return nil
            }
        }
    }

    let request: CommandConfirmationRequest
    @Binding var customText: String
    let onSelectChoice: (CommandConfirmationChoice) -> Void
    let onSubmitCustom: () -> Void
    let onDismiss: () -> Void

    @State private var selectedChoiceIndex: Int? = nil
    @State private var targetOption: TargetOption = .lastTouchedExercise
    @State private var adjustmentOption: AdjustmentOption = .none
    @State private var stepIndex: Int = 0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pregunta \(currentQuestionNumber) de \(totalQuestions)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(request.prompt)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(currentQuestionKind.title)
                            .font(.headline)

                        switch currentQuestionKind {
                        case .intent:
                            intentQuestion
                        case .target:
                            targetQuestion
                        case .adjustment:
                            adjustmentQuestion
                        }

                        customComposer
                    }
                    .padding(16)
                }

                Divider()

                HStack(spacing: 12) {
                    if stepIndex > 0 {
                        Button("Atrás") {
                            stepIndex = max(0, stepIndex - 1)
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if isLastQuestion {
                        Button("Aplicar") {
                            applyResolvedChoice()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedChoice == nil)
                    } else {
                        Button("Siguiente") {
                            stepIndex = min(totalQuestions - 1, stepIndex + 1)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAdvance)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Aclarar comando")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        onDismiss()
                    }
                }
            }
            .onAppear {
                configureInitialState()
            }
            .onChange(of: selectedChoiceIndex) { _, _ in
                if let command = selectedChoice?.command {
                    targetOption = defaultTargetOption(for: command)
                }
                clampStepIndex()
            }
        }
    }

    private var choices: [CommandConfirmationChoice] { request.choices }

    private var selectedChoice: CommandConfirmationChoice? {
        guard let selectedChoiceIndex, choices.indices.contains(selectedChoiceIndex) else {
            return nil
        }
        return choices[selectedChoiceIndex]
    }

    private var questionKinds: [QuestionKind] {
        var result: [QuestionKind] = []

        if needsIntentQuestion {
            result.append(.intent)
        }

        if let command = selectedChoice?.command {
            if supportsTargetQuestion(for: command) {
                result.append(.target)
            }
            if supportsAdjustmentQuestion(for: command) {
                result.append(.adjustment)
            }
        }

        if result.isEmpty {
            result.append(.intent)
        }

        return result
    }

    private var totalQuestions: Int { max(1, questionKinds.count) }

    private var currentQuestionKind: QuestionKind {
        questionKinds[min(stepIndex, questionKinds.count - 1)]
    }

    private var currentQuestionNumber: Int { min(stepIndex + 1, totalQuestions) }

    private var isLastQuestion: Bool { stepIndex >= totalQuestions - 1 }

    private var canAdvance: Bool {
        switch currentQuestionKind {
        case .intent:
            return selectedChoice != nil
        case .target, .adjustment:
            return true
        }
    }

    private var needsIntentQuestion: Bool {
        choices.count > 1 || selectedChoice == nil
    }

    private var intentQuestion: some View {
        VStack(alignment: .leading, spacing: 10) {
            if choices.isEmpty {
                Text("No hay opciones sugeridas por ahora. Escribe tu comando personalizado abajo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                    selectableRow(
                        title: choice.label,
                        isSelected: index == selectedChoiceIndex
                    ) {
                        selectedChoiceIndex = index
                    }
                }
            }
        }
    }

    private var targetQuestion: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(TargetOption.allCases) { option in
                selectableRow(title: option.label, isSelected: targetOption == option) {
                    targetOption = option
                }
            }
        }
    }

    private var adjustmentQuestion: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(AdjustmentOption.allCases) { option in
                selectableRow(title: option.label, isSelected: adjustmentOption == option) {
                    adjustmentOption = option
                }
            }
        }
    }

    private var customComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().padding(.vertical, 6)

            Text("O escribe una opción personalizada")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Escribe el comando exacto...", text: $customText, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            Button("Enviar texto personalizado") {
                onSubmitCustom()
            }
            .buttonStyle(.bordered)
            .disabled(customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func selectableRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(title)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func configureInitialState() {
        if selectedChoiceIndex == nil, choices.count == 1 {
            selectedChoiceIndex = 0
        }

        if let command = selectedChoice?.command {
            targetOption = defaultTargetOption(for: command)
        }

        clampStepIndex()
    }

    private func clampStepIndex() {
        let maxStep = max(0, totalQuestions - 1)
        stepIndex = min(stepIndex, maxStep)
    }

    private func applyResolvedChoice() {
        guard let baseChoice = selectedChoice else { return }

        var command = baseChoice.command
        command = applyTarget(command, option: targetOption)
        command = applyAdjustment(command, option: adjustmentOption)

        let label = "\(baseChoice.label) · \(targetOption.label) · \(adjustmentOption.label)"
        onSelectChoice(CommandConfirmationChoice(label: label, command: command))
    }

    private func supportsTargetQuestion(for command: ParsedWorkoutCommand) -> Bool {
        switch command {
        case .addSet, .addMultipleSets, .duplicateSet, .deleteSet, .updateSet:
            return true
        default:
            return false
        }
    }

    private func supportsAdjustmentQuestion(for command: ParsedWorkoutCommand) -> Bool {
        switch command {
        case .addSet, .addMultipleSets, .duplicateSet, .updateSet:
            return true
        default:
            return false
        }
    }

    private func defaultTargetOption(for command: ParsedWorkoutCommand) -> TargetOption {
        switch command {
        case .duplicateSet, .deleteSet, .updateSet:
            return .lastTouchedSet
        default:
            return .lastTouchedExercise
        }
    }

    private func applyTarget(_ command: ParsedWorkoutCommand, option: TargetOption) -> ParsedWorkoutCommand {
        switch command {
        case .addSet(var payload):
            payload.target = exerciseTarget(for: option)
            return .addSet(payload)
        case .addMultipleSets(var payload):
            payload.target = exerciseTarget(for: option)
            return .addMultipleSets(payload)
        case .duplicateSet(var payload):
            payload.target = setTarget(for: option)
            return .duplicateSet(payload)
        case .deleteSet(var payload):
            payload.target = setTarget(for: option)
            return .deleteSet(payload)
        case .updateSet(var payload):
            payload.target = setTarget(for: option)
            return .updateSet(payload)
        default:
            return command
        }
    }

    private func exerciseTarget(for option: TargetOption) -> WorkoutCommandTarget {
        switch option {
        case .lastTouchedExercise: return .lastTouchedExercise
        case .previousExercise: return .previousExercise
        case .selectedExercise: return .selectedExercise
        case .lastTouchedSet: return .lastTouchedExercise
        }
    }

    private func setTarget(for option: TargetOption) -> WorkoutCommandTarget {
        switch option {
        case .lastTouchedSet: return .lastTouchedSet
        case .lastTouchedExercise: return .lastTouchedExercise
        case .previousExercise: return .previousExercise
        case .selectedExercise: return .selectedExercise
        }
    }

    private func applyAdjustment(_ command: ParsedWorkoutCommand, option: AdjustmentOption) -> ParsedWorkoutCommand {
        guard option != .none else { return command }

        switch command {
        case .addSet(var payload):
            if let repsDelta = option.repsDelta {
                let base = payload.set.reps ?? 8
                payload.set.reps = max(0, base + repsDelta)
            }
            if let weightDelta = option.weightDelta {
                let base = payload.set.weight ?? 0
                payload.set.weight = max(0, base + weightDelta)
            }
            return .addSet(payload)

        case .addMultipleSets(var payload):
            payload.sets = payload.sets.map { item in
                var set = item
                if let repsDelta = option.repsDelta {
                    let base = set.reps ?? 8
                    set.reps = max(0, base + repsDelta)
                }
                if let weightDelta = option.weightDelta {
                    let base = set.weight ?? 0
                    set.weight = max(0, base + weightDelta)
                }
                return set
            }
            return .addMultipleSets(payload)

        case .duplicateSet(var payload):
            var modifier = payload.modifier ?? WorkoutCommandModifier()
            if let weightDelta = option.weightDelta {
                modifier.weightDelta = (modifier.weightDelta ?? 0) + weightDelta
            }
            if let repsDelta = option.repsDelta {
                modifier.repsDelta = (modifier.repsDelta ?? 0) + repsDelta
            }
            payload.modifier = modifier
            return .duplicateSet(payload)

        case .updateSet(var payload):
            if let weightDelta = option.weightDelta {
                payload.modifier.weightDelta = (payload.modifier.weightDelta ?? 0) + weightDelta
            }
            if let repsDelta = option.repsDelta {
                payload.modifier.repsDelta = (payload.modifier.repsDelta ?? 0) + repsDelta
            }
            return .updateSet(payload)

        default:
            return command
        }
    }
}
