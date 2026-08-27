import SwiftUI
import TildeLabKit

struct LabLearningLedgerView: View {
    let snapshot: LabLearningLedgerSnapshot?

    var body: some View {
        Group {
            if let snapshot {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        header(snapshot)
                        stagedResearchProgram(snapshot)
                        currentEvidence(snapshot)
                        researchQueue(snapshot)
                        promotionPath(snapshot)
                        archivedEvidence(snapshot)
                    }
                    .padding(24)
                    .frame(maxWidth: 1_000, alignment: .leading)
                }
            } else {
                ContentUnavailableView(
                    "Learning ledger unavailable",
                    systemImage: "brain.head.profile",
                    description: Text("The bundled aggregate-only learning history could not be loaded.")
                )
            }
        }
    }

    private func header(_ snapshot: LabLearningLedgerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tilde Learning Ledger")
                .font(.largeTitle.bold())
            Text(snapshot.mission)
                .font(.title3)
            Text("\(snapshot.researchProgram.count) research stages · \(registeredHypothesisCount(snapshot)) hypotheses · \(snapshot.researchQueue.count) executable next steps")
                .foregroundStyle(.secondary)
            Label(
                snapshot.privacy.safeToCheckIn
                    ? "Aggregate-only · no personal writing or raw model output"
                    : "Privacy contract failed",
                systemImage: snapshot.privacy.safeToCheckIn ? "lock.shield.fill" : "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(snapshot.privacy.safeToCheckIn ? .green : .red)
        }
    }

    private func stagedResearchProgram(_ snapshot: LabLearningLedgerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Research roadmap",
                subtitle: "One active stage at a time; later bets stay locked until the current exit gate passes"
            )
            ForEach(snapshot.researchProgram.sorted(by: { $0.order < $1.order })) { stage in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("STAGE \(stage.order)")
                            .font(.caption2.bold().monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(stage.status.title.uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(researchStageColor(stage.status))
                        Spacer()
                        Image(systemName: researchStageSymbol(stage.status))
                            .foregroundStyle(researchStageColor(stage.status))
                    }
                    Text(stage.title)
                        .font(.headline)
                    Text(stage.objective)
                        .font(.callout)

                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(stage.hypotheses) { hypothesis in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(hypothesis.id)
                                    .font(.caption.bold().monospaced())
                                    .foregroundStyle(researchStageColor(stage.status))
                                    .frame(width: 30, alignment: .leading)
                                Text(hypothesis.title)
                                    .font(.caption)
                            }
                        }
                    }

                    Label("Exit gate: \(stage.exitGate)", systemImage: "flag.checkered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .opacity(stage.status == .locked ? 0.72 : 1)
            }
        }
    }

    private func currentEvidence(_ snapshot: LabLearningLedgerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("What we know", subtitle: "Current decisions, boundaries, and directional evidence")
            ForEach(snapshot.currentLearnings.sorted(by: newestFirst)) { entry in
                learningCard(entry)
            }
        }
    }

    private func researchQueue(_ snapshot: LabLearningLedgerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("What we test next", subtitle: "Ordered by expected value, not novelty")
            ForEach(snapshot.researchQueue.sorted(by: { $0.priority < $1.priority })) { question in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(question.priority). \(question.question)")
                        .font(.headline)
                    Text(question.nextExperiment)
                    Text("Success: \(question.successCriteria)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func promotionPath(_ snapshot: LabLearningLedgerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("How evidence reaches production", subtitle: "Every stage can reject the candidate")
            ForEach(snapshot.promotionPath.sorted(by: { $0.order < $1.order })) { stage in
                HStack(alignment: .top, spacing: 12) {
                    Text(stage.order.formatted())
                        .font(.headline.monospacedDigit())
                        .frame(width: 24, height: 24)
                        .background(.tint, in: Circle())
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stage.title).font(.headline)
                        Text(stage.requirement)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func archivedEvidence(_ snapshot: LabLearningLedgerSnapshot) -> some View {
        DisclosureGroup("Archived protocols and superseded results") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(snapshot.archivedLearnings.sorted(by: newestFirst)) { entry in
                    learningCard(entry)
                }
            }
            .padding(.top, 10)
        }
        .font(.headline)
    }

    private func learningCard(_ entry: LabLearningLedgerEntry) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(entry.status.title.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(statusColor(entry.status))
                Text(entry.area.replacingOccurrences(of: "-", with: " ").uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let evaluations = entry.evaluationCount {
                    Text("\(evaluations.formatted()) evals")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(entry.title).font(.headline)
            Text(entry.finding)
            Text("Decision: \(entry.decision)")
                .font(.callout.weight(.medium))
            if !entry.limitations.isEmpty {
                Text("Limit: \(entry.limitations.joined(separator: " "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title2.bold())
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func newestFirst(_ lhs: LabLearningLedgerEntry, _ rhs: LabLearningLedgerEntry) -> Bool {
        if lhs.recordedAt != rhs.recordedAt { return lhs.recordedAt > rhs.recordedAt }
        return lhs.id < rhs.id
    }

    private func statusColor(_ status: LabLearningStatus) -> Color {
        switch status {
        case .adopted: .green
        case .rejected: .red
        case .directional: .blue
        case .superseded: .secondary
        case .incomplete: .orange
        case .operational: .purple
        case .boundary: .indigo
        }
    }

    private func researchStageColor(_ status: LabResearchProgramStageStatus) -> Color {
        switch status {
        case .active: .orange
        case .locked: .secondary
        case .completed: .green
        }
    }

    private func researchStageSymbol(_ status: LabResearchProgramStageStatus) -> String {
        switch status {
        case .active: "arrow.right.circle.fill"
        case .locked: "lock.fill"
        case .completed: "checkmark.circle.fill"
        }
    }

    private func registeredHypothesisCount(_ snapshot: LabLearningLedgerSnapshot) -> Int {
        snapshot.researchProgram
            .flatMap(\.hypotheses)
            .filter { $0.id.hasPrefix("H") }
            .count
    }
}
