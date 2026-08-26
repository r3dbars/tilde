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
            Text("\(snapshot.currentLearnings.count) current learnings · \(snapshot.archivedLearnings.count) archived · \(snapshot.researchQueue.count) queued experiments")
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
}
