import SwiftUI
import TildeLabKit

struct LabModelBenchmarksView: View {
    let snapshot: LabModelBenchmarkSnapshot?

    var body: some View {
        Group {
            if let snapshot {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Directional Model Results")
                            .font(.largeTitle.bold())
                        Text("Checked-in aggregate results · \(snapshot.suiteName)")
                            .foregroundStyle(.secondary)
                        Text(snapshot.comparisonPolicy)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Table(snapshot.fullComparisons) {
                        TableColumn("Model") { Text($0.label) }
                        TableColumn("Score") { Text($0.qualityScore.formatted()) }
                        TableColumn("Useful") { Text($0.useful.formatted()) }
                        TableColumn("Wrong") { Text($0.wrong.formatted()) }
                        TableColumn("Silent") { Text($0.silent.formatted()) }
                        TableColumn("Bad") {
                            Text(($0.badSuggestionRate * 100).formatted(.number.precision(.fractionLength(1))) + "%")
                        }
                        TableColumn("Net saved") {
                            Text(($0.netKeystrokeSavingsRate * 100).formatted(.number.precision(.fractionLength(1))) + "%")
                        }
                        TableColumn("First p95") {
                            Text($0.firstTokenP95Milliseconds.map { "\($0) ms" } ?? "—")
                        }
                        TableColumn("Total p95") {
                            Text($0.totalP95Milliseconds.map { "\($0) ms" } ?? "—")
                        }
                    }

                    if snapshot.entries.contains(where: { $0.evaluations != 360 }) {
                        Text("Short ceiling runs are retained in the catalog but excluded from this ranking.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Protocol groups: \(Set(snapshot.fullComparisons.map(\.comparisonGroupID)).count). Match protocol IDs before making a strict speed or quality claim.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(snapshot.promotedConfigurations) { configuration in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Promoted experimental configuration")
                                .font(.headline)
                            Text(configuration.label)
                                .font(.title3.bold())
                            Text("Temperature \(configuration.temperature.formatted()) · \(configuration.predictionTokens) generated tokens · \(configuration.maximumVisibleWords)-word cap")
                                .foregroundStyle(.secondary)
                            Text("Score \(configuration.qualityScore) · Useful \(configuration.useful) · Wrong \(configuration.wrong) · Silent \(configuration.silent) · Total p95 \(configuration.totalP95Milliseconds) ms")
                                .font(.system(.body, design: .monospaced))
                            Text("Net typing saved \((configuration.netKeystrokeSavingsRate * 100).formatted(.number.precision(.fractionLength(1))))% · baseline quality \(configuration.baselineQualityScore)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(configuration.evidenceNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(24)
            } else {
                ContentUnavailableView(
                    "Model results unavailable",
                    systemImage: "chart.bar.xaxis",
                    description: Text("The bundled aggregate benchmark catalog could not be loaded.")
                )
            }
        }
    }
}
