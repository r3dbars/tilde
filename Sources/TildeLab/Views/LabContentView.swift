import SwiftUI
import TildeLabKit

struct LabContentView: View {
    @Bindable var store: LabWorkspaceStore

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selection) {
                Section("Lab") {
                    Label("Autoresearch", systemImage: "arrow.triangle.branch")
                        .tag(LabSidebarSelection.research)
                    Label("Learning Ledger", systemImage: "brain.head.profile")
                        .tag(LabSidebarSelection.learningLedger)
                    Label("Model Results", systemImage: "chart.bar.xaxis")
                        .tag(LabSidebarSelection.modelBenchmarks)
                    ForEach(LabBenchKind.allCases) { bench in
                        Label(bench.title, systemImage: bench.systemImage)
                            .tag(LabSidebarSelection.bench(bench))
                    }
                }

                Section("Runs") {
                    if store.reports.isEmpty {
                        Text("No completed runs")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.reports) { report in
                            LabRunSidebarRow(report: report)
                                .tag(LabSidebarSelection.run(report.id))
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            switch store.selection {
            case .research:
                LabResearchView(store: store)
            case .learningLedger:
                LabLearningLedgerView(snapshot: store.learningLedgerSnapshot)
            case .modelBenchmarks:
                LabModelBenchmarksView(snapshot: store.modelBenchmarkSnapshot)
            case let .bench(bench):
                switch bench {
                case .reply:
                    LabExperimentView(store: store)
                case .judgment:
                    LabJudgmentBenchView(store: store)
                case .sceneMemory:
                    LabSceneMemoryBenchView(store: store)
                case .personalization:
                    LabPersonalizationBenchView(store: store)
                case .interaction:
                    LabInteractionBenchView(store: store)
                case .performance:
                    LabPerformanceBenchView(store: store)
                }
            case .run:
                if let report = store.selectedReport {
                    LabRunDetailView(
                        report: report,
                        baseline: store.baseline(for: report),
                        isPinnedBaseline: store.pinnedBaselineRunID == report.id,
                        scenario: { store.scenario(for: $0, report: report) },
                        onPinBaseline: { store.pinBaseline(report) },
                        onDelete: { store.delete(report) }
                    )
                } else {
                    ContentUnavailableView("Run unavailable", systemImage: "questionmark.folder")
                }
            }
        }
        .alert("Tilde Lab", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "Unknown error")
        }
    }
}

private struct LabRunSidebarRow: View {
    let report: LabRunReport

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: verdictIcon)
                .foregroundStyle(verdictColor)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(report.verdict.title)
                    .lineLimit(1)
                Text("\(report.arm.id) · \(report.displayScore) · \(report.finishedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            Image(systemName: report.effectiveEvidenceEligibility.eligible
                  ? "checkmark.shield.fill" : "exclamationmark.shield")
                .foregroundStyle(report.effectiveEvidenceEligibility.eligible ? .green : .secondary)
                .help(report.effectiveEvidenceEligibility.eligible
                      ? "Decision-grade evidence" : "Not decision-grade evidence")
        }
    }

    private var verdictIcon: String {
        switch report.verdict {
        case .eligible: "checkmark.seal.fill"
        case .candidate: "circle.lefthalf.filled"
        case .degenerateSilence: "speaker.slash.fill"
        case .incomplete: "exclamationmark.triangle.fill"
        }
    }

    private var verdictColor: Color {
        switch report.verdict {
        case .eligible: .green
        case .candidate: .blue
        case .degenerateSilence, .incomplete: .orange
        }
    }
}
