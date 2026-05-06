import SwiftUI

struct AddWorkoutOrExerciseView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel: AddWorkoutOrExerciseViewModel

    init(dayKey: String) {
        _viewModel = State(wrappedValue: AddWorkoutOrExerciseViewModel(dayKey: dayKey, router: AppRouter()))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassPageBackground()
                searchAndFilterBar()
                    .zIndex(2)

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            if !viewModel.filteredTemplates.isEmpty || viewModel.searchText.isEmpty {
                                templatesSection()
                            }

                            if !viewModel.ejerciciosBaseFiltrados.isEmpty || viewModel.searchText.isEmpty {
                                catalogSection()
                            }

                            if viewModel.ejerciciosBaseFiltrados.isEmpty && viewModel.filteredTemplates.isEmpty && !viewModel.searchText.isEmpty {
                                emptyState()
                            }

                            if let error = viewModel.errorMessage, !error.isEmpty {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 120)
                        .padding(.bottom, 20)
                    }
                }
                .zIndex(1)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            viewModel.wireRouter(router)
            viewModel.wireDependencies(
                workoutRepository: environment.workoutRepository,
                exerciseRepository: environment.exerciseRepository,
                exerciseIdentityResolver: environment.exerciseIdentityResolver
            )
            viewModel.load()
        }
    }

    @ViewBuilder
    private func searchAndFilterBar() -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Search exercise...", text: $viewModel.searchText)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .setlogGlass(.regular, in: Capsule())

                    Button {
                        viewModel.startNewWorkoutSession()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .setlogGlass(.regular, in: Capsule())
                    .buttonStyle(.plain)
                    .setlogTappable()

                    Button {
                        viewModel.startStepsSession()
                    } label: {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .setlogGlass(.regular, in: Capsule())
                    .buttonStyle(.plain)
                    .setlogTappable()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                HStack(spacing: 12) {
                    Menu {
                        Button("All") { viewModel.selectedMuscle = nil }
                        ForEach(viewModel.todosLosMusculos, id: \.self) { muscle in
                            Button(displayMuscleName(muscle)) {
                                viewModel.selectedMuscle = viewModel.selectedMuscle == muscle ? nil : muscle
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(viewModel.selectedMuscle.map(displayMuscleName) ?? "Muscles")
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .setlogGlass(.regular, in: Capsule())
                    }

                    Menu {
                        Button("All") { viewModel.selectedEquipment = nil }
                        ForEach(viewModel.todosLosEquipment, id: \.self) { equipment in
                            Button(equipment.capitalized) {
                                viewModel.selectedEquipment = viewModel.selectedEquipment == equipment ? nil : equipment
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(viewModel.selectedEquipment?.capitalized ?? "Equipment")
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .setlogGlass(.regular, in: Capsule())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            Spacer().frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func templatesSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Templates")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? .white : .black)
                .padding(.horizontal, 20)

            LiquidGlassOuterCard(cornerRadius: 12) {
                LazyVStack(spacing: 0) {
                    ForEach(Array((viewModel.searchText.isEmpty ? viewModel.favoriteTemplates : viewModel.filteredTemplates).prefix(10).enumerated()), id: \.element.id) { index, template in
                        Button {
                            viewModel.applyTemplate(template)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(colorScheme == .dark ? .white : .black)

                                    Text(template.snippetType.contains("empty") ? "Empty template" : "With sets")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)

                        if index < min(viewModel.searchText.isEmpty ? viewModel.favoriteTemplates.count : viewModel.filteredTemplates.count, 10) - 1 {
                            Divider().background(Color.secondary.opacity(0.2))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func catalogSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Catalog")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? .white : .black)
                .padding(.horizontal, 20)

            LiquidGlassOuterCard(cornerRadius: 12) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.ejerciciosBaseFiltrados.enumerated()), id: \.element.id) { index, exercise in
                        Button {
                            viewModel.addEjercicioBase(exercise)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(exercise.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(colorScheme == .dark ? .white : .black)

                                    HStack(spacing: 8) {
                                        if !exercise.musculos.isEmpty {
                                            Text(exercise.musculos.map(displayMuscleName).joined(separator: ", "))
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        if !exercise.equipment.isEmpty {
                                            if !exercise.musculos.isEmpty {
                                                Circle().fill(Color.secondary).frame(width: 4, height: 4)
                                            }
                                            Text(exercise.equipment.joined(separator: ", "))
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    if let description = exercise.description, !description.isEmpty {
                                        Text(description)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary.opacity(0.8))
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)

                        if index < viewModel.ejerciciosBaseFiltrados.count - 1 {
                            Divider().background(Color.secondary.opacity(0.2))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func emptyState() -> some View {
        VStack(spacing: 16) {
            Text("No exercises found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? .white : .black)

            Text("Create a custom exercise")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Button {
                viewModel.addManualExercise(name: viewModel.searchText)
            } label: {
                Text("Create Exercise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .setlogGlass(.regular, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 40)
    }
}
