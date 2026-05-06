import Foundation

@MainActor
@Observable
final class StatsViewModel {

    var summaries: [ExerciseStatsSummaryDTO] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private var statsRepository: StatsRepositoryProtocol?

    func wire(statsRepository: StatsRepositoryProtocol) {
        self.statsRepository = statsRepository
    }

    func load() {
        guard !isLoading else { return }
        guard let statsRepository else { return }

        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                summaries = try await statsRepository.fetchExerciseSummaries(range: .ninetyDays)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
