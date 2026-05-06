import SwiftUI

struct StatsView: View {

    @Environment(\.appEnvironment) private var environment
    @State private var viewModel = StatsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 24)
                } else if viewModel.summaries.isEmpty {
                    EmptyStateView(
                        systemImage: "chart.bar.xaxis",
                        title: "No stats yet",
                        subtitle: "Log more sets to build your stats."
                    )
                    .padding(.top, 24)
                } else {
                    ForEach(viewModel.summaries, id: \.savedExerciseID) { summary in
                        statsCard(summary: summary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .safeAreaBar(edge: .top, spacing: 0) {
            HStack {
                Text("Stats")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.wire(statsRepository: environment.statsRepository)
            viewModel.load()
        }
    }

    @ViewBuilder
    private func statsCard(summary: ExerciseStatsSummaryDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.name)
                .font(.headline)

            Text("Sessions: \(summary.sessionCount) · Sets: \(summary.setCount)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Best e1RM: \(summary.bestE1RM, specifier: "%.1f")")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Volume: \(summary.totalVolume, specifier: "%.0f")")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
