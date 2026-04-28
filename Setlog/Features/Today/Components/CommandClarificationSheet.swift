import SwiftUI

struct CommandClarificationSheet: View {

    private enum QuestionKind {
        case intent
        case target
        case adjustment

        var title: String {
            switch self {
            case .intent:     return "¿Qué querías hacer?"
            case .target:     return "¿Dónde aplicarlo?"
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
            case .previousExercise:    return "Ejercicio anterior"
            case .selectedExercise:    return "Ejercicio seleccionado"
            case .lastTouchedSet:      return "Última serie"
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
            case .none:        return "Sin cambios"
            case .minusTenKg:  return "-10 kg"
            case .plusTenKg:   return "+10 kg"
            case .minusOneRep: return "-1 repetición"
            case .plusOneRep:  return "+1 repetición"
            }
        }
        var weightDelta: Double? {
            switch self { case .minusTenKg: return -10; case .plusTenKg: return 10; default: return nil }
        }
        var repsDelta: Int? {
            switch self { case .minusOneRep: return -1; case .plusOneRep: return 1; default: return nil }
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
    @State private var isEditingCustom: Bool = false
    @FocusState private var customFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(currentQuestionKind.title)
                            .font(.headline)
                        switch currentQuestionKind {
                        case .intent:     intentQuestion
                        case .target:     targetQuestion
                        case .adjustment: adjustmentQuestion
                        }
                    }
                    .padding(16)
                }
                Divider()
                bottomBar
            }
            .navigationTitle("Aclarar comando")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { onDismiss() }
                }
            }
            .onAppear { configureInitialState() }
            .onChange(of: selectedChoiceIndex) { _, _ in
                isEditingCustom = false
                if let command = selectedChoice?.command {
                    targetOption = defaultTargetOption(for: command)
                }
                clampStepIndex()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pregunta \(currentQuestionNumber) de \(totalQuestions)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            // FM-generated question shown prominently; fallback to generic prompt
            if let generated = request.generatedQuestion, !generated.isEmpty {
                Text(generated)
                    .font(.title3.weight(.semibold))
            } else {
                Text(request.prompt)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if stepIndex > 0 {
                Button("Atrás") { stepIndex = max(0, stepIndex - 1) }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if isLastQuestion {
                Button("Aplicar") { applyResolvedChoice() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedChoice == nil && !isEditingCustom)
            } else {
                Button("Siguiente") { stepIndex = min(totalQuestions - 1, stepIndex + 1) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAdvance)
            }
        }
        .padding(16)
    }

    // MARK: - Questions

    private var choices: [CommandConfirmationChoice] { request.choices }

    private var intentQuestion: some View {
        VStack(alignment: .leading, spacing: 10) {
            if choices.isEmpty {
                Text("No hay opciones sugeridas. Usa el campo de texto abajo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                    selectableRow(title: choice.label, isSelected: index == selectedChoiceIndex) {
                        selectedChoiceIndex = index
                    }
                }
            }

            // "Otra opción" row — expands inline to a text field when tapped
            if isEditingCustom {
                HStack(spacing: 10) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    TextField("Escribe tu opción...", text: $customText)
                        .focused($customFieldFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            if !customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSubmitCustom()
                            }
                        }
                    Button {
                        isEditingCustom = false
                        customText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
                .onAppear { customFieldFocused = true }
            } else {
                Button {
                    selectedChoiceIndex = nil
                    isEditingCustom = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.circle")
                            .foregroundStyle(.secondary)
                        Text("Otra opción...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
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

    // MARK: - Row component

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

    // MARK: - Step logic

    private var selectedChoice: CommandConfirmationChoice? {
        guard let idx = selectedChoiceIndex, choices.indices.contains(idx) else { return nil }
        return choices[idx]
    }

    private var questionKinds: [QuestionKind] {
        var result: [QuestionKind] = []
        if needsIntentQuestion { result.append(.intent) }
        if let command = selectedChoice?.command {
            if supportsTargetQuestion(for: command)     { result.append(.target) }
            if supportsAdjustmentQuestion(for: command) { result.append(.adjustment) }
        }
        return result.isEmpty ? [.intent] : result
    }

    private var totalQuestions: Int     { max(1, questionKinds.count) }
    private var currentQuestionKind: QuestionKind { questionKinds[min(stepIndex, questionKinds.count - 1)] }
    private var currentQuestionNumber: Int { min(stepIndex + 1, totalQuestions) }
    private var isLastQuestion: Bool    { stepIndex >= totalQuestions - 1 }
    private var needsIntentQuestion: Bool { choices.count > 1 || selectedChoice == nil }

    private var canAdvance: Bool {
        switch currentQuestionKind {
        case .intent: return selectedChoice != nil || isEditingCustom
        case .target, .adjustment: return true
        }
    }

    // MARK: - Apply

    private func applyResolvedChoice() {
        if isEditingCustom {
            onSubmitCustom()
            return
        }
        guard let baseChoice = selectedChoice else { return }
        var command = baseChoice.command
        command = applyTarget(command, option: targetOption)
        command = applyAdjustment(command, option: adjustmentOption)
        let label = "\(baseChoice.label) · \(targetOption.label) · \(adjustmentOption.label)"
        onSelectChoice(CommandConfirmationChoice(label: label, command: command))
    }

    private func configureInitialState() {
        if selectedChoiceIndex == nil, choices.count == 1 { selectedChoiceIndex = 0 }
        if let command = selectedChoice?.command { targetOption = defaultTargetOption(for: command) }
        clampStepIndex()
    }

    private func clampStepIndex() {
        stepIndex = min(stepIndex, max(0, totalQuestions - 1))
    }

    // MARK: - Command mutation helpers

    private func supportsTargetQuestion(for command: ParsedWorkoutCommand) -> Bool {
        switch command {
        case .addSet, .addMultipleSets, .duplicateSet, .deleteSet, .updateSet: return true
        default: return false
        }
    }

    private func supportsAdjustmentQuestion(for command: ParsedWorkoutCommand) -> Bool {
        switch command {
        case .addSet, .addMultipleSets, .duplicateSet, .updateSet: return true
        default: return false
        }
    }

    private func defaultTargetOption(for command: ParsedWorkoutCommand) -> TargetOption {
        switch command {
        case .duplicateSet, .deleteSet, .updateSet: return .lastTouchedSet
        default: return .lastTouchedExercise
        }
    }

    private func applyTarget(_ command: ParsedWorkoutCommand, option: TargetOption) -> ParsedWorkoutCommand {
        switch command {
        case .addSet(var p):
            p.target = exerciseTarget(for: option); return .addSet(p)
        case .addMultipleSets(var p):
            p.target = exerciseTarget(for: option); return .addMultipleSets(p)
        case .duplicateSet(var p):
            p.target = setTarget(for: option); return .duplicateSet(p)
        case .deleteSet(var p):
            p.target = setTarget(for: option); return .deleteSet(p)
        case .updateSet(var p):
            p.target = setTarget(for: option); return .updateSet(p)
        default: return command
        }
    }

    private func exerciseTarget(for option: TargetOption) -> WorkoutCommandTarget {
        switch option {
        case .lastTouchedExercise: return .lastTouchedExercise
        case .previousExercise:    return .previousExercise
        case .selectedExercise:    return .selectedExercise
        case .lastTouchedSet:      return .lastTouchedExercise
        }
    }

    private func setTarget(for option: TargetOption) -> WorkoutCommandTarget {
        switch option {
        case .lastTouchedSet:      return .lastTouchedSet
        case .lastTouchedExercise: return .lastTouchedExercise
        case .previousExercise:    return .previousExercise
        case .selectedExercise:    return .selectedExercise
        }
    }

    private func applyAdjustment(_ command: ParsedWorkoutCommand, option: AdjustmentOption) -> ParsedWorkoutCommand {
        guard option != .none else { return command }
        switch command {
        case .addSet(var p):
            if let d = option.repsDelta   { p.set.reps   = max(0, (p.set.reps ?? 8) + d) }
            if let d = option.weightDelta { p.set.weight = max(0, (p.set.weight ?? 0) + d) }
            return .addSet(p)
        case .addMultipleSets(var p):
            p.sets = p.sets.map { var s = $0
                if let d = option.repsDelta   { s.reps   = max(0, (s.reps ?? 8) + d) }
                if let d = option.weightDelta { s.weight = max(0, (s.weight ?? 0) + d) }
                return s }
            return .addMultipleSets(p)
        case .duplicateSet(var p):
            var mod = p.modifier ?? WorkoutCommandModifier()
            if let d = option.weightDelta { mod.weightDelta = (mod.weightDelta ?? 0) + d }
            if let d = option.repsDelta   { mod.repsDelta   = (mod.repsDelta   ?? 0) + d }
            p.modifier = mod; return .duplicateSet(p)
        case .updateSet(var p):
            if let d = option.weightDelta { p.modifier.weightDelta = (p.modifier.weightDelta ?? 0) + d }
            if let d = option.repsDelta   { p.modifier.repsDelta   = (p.modifier.repsDelta   ?? 0) + d }
            return .updateSet(p)
        default: return command
        }
    }
}
