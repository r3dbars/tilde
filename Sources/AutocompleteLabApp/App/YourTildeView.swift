import SwiftUI

@MainActor
final class YourTildeViewModel: ObservableObject {
    @Published private(set) var snapshot = TildeProgressSnapshot(
        wordsSavedToday: 0,
        wordsSavedLifetime: 0,
        wordsLearnedFrom: 0,
        activeWritingDays: 0,
        personalSuggestionsToday: 0,
        personalizationStage: .loading,
        candidateAccuracy: nil,
        baselineAccuracy: nil
    )

    private let personalHistory: PersonalHistoryController
    private var refreshGeneration: UInt64 = 0

    init(personalHistory: PersonalHistoryController) {
        self.personalHistory = personalHistory
    }

    func refresh() {
        refreshGeneration &+= 1
        let generation = refreshGeneration
        Task { [weak self, personalHistory] in
            let next = await TildeProgress.snapshot(personalHistory: personalHistory)
            guard let self, generation == self.refreshGeneration, !Task.isCancelled else { return }
            self.snapshot = next
        }
    }
}

struct YourTildeSummaryView: View {
    @ObservedObject var model: YourTildeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(stageTitle)
                    .font(.headline)
                Text(stageDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let stageProgress {
                    ProgressView(value: stageProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                }
            }

            if let milestone {
                Label(milestone, systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(alignment: .top, spacing: 0) {
                metric(
                    value: model.snapshot.wordsSavedToday.formatted(),
                    label: "words saved today",
                    detail: "\(model.snapshot.wordsSavedLifetime.formatted()) all time"
                )
                Divider().frame(height: 58)
                metric(
                    value: model.snapshot.wordsLearnedFrom.formatted(),
                    label: "words learned from"
                )
                Divider().frame(height: 58)
                metric(
                    value: model.snapshot.activeWritingDays.formatted(),
                    label: "writing days"
                )
            }

            if model.snapshot.personalSuggestionsToday > 0 {
                Text("\(model.snapshot.personalSuggestionsToday.formatted()) suggestions came from your patterns today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Label("All learning stays on this Mac.", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func metric(value: String, label: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }

    private var stageTitle: String {
        switch model.snapshot.personalizationStage {
        case .off: "Personalization is off"
        case .loading: "Loading your progress"
        case .unavailable: "Progress is unavailable"
        case let .learningWords(current, _) where current < 500: "Getting to know you"
        case .learningWords: "Learning your style"
        case .buildingConfidence: "Building confidence"
        case .validating: "Still tuning"
        case .tuned: "Tuned to you"
        }
    }

    private var stageDetail: String {
        switch model.snapshot.personalizationStage {
        case .off:
            "Turn on Personal Learning below to help Tilde adapt to your writing."
        case .loading:
            "Tilde is loading aggregate learning progress from this Mac."
        case .unavailable:
            "Tilde could not read learning progress. Your writing was not exposed."
        case let .learningWords(current, goal):
            "\(current.formatted()) of \(goal.formatted()) words learned from. Keep writing normally."
        case let .buildingConfidence(days, goal):
            "\(days) of \(goal) writing days. Tilde is testing which personal patterns actually help."
        case .validating:
            "Tilde hasn’t proven a personal improvement yet. Keep writing normally."
        case let .tuned(candidate, baseline):
            "Your personal model is beating the generic model: \(percent(candidate)) vs \(percent(baseline))."
        }
    }

    private var stageProgress: Double? {
        switch model.snapshot.personalizationStage {
        case .off, .unavailable: 0
        case .loading, .validating: nil
        case let .learningWords(current, goal):
            goal > 0 ? min(1, Double(current) / Double(goal)) : 0
        case let .buildingConfidence(days, goal):
            goal > 0 ? min(1, Double(days) / Double(goal)) : 0
        case .tuned: 1
        }
    }

    private var milestone: String? {
        if model.snapshot.activeWritingDays >= 14 {
            return "14 writing days — enough history to measure personalization."
        }
        if model.snapshot.wordsLearnedFrom >= 2_000 {
            return "2,000 words — enough writing to begin validating the personal model."
        }
        if model.snapshot.wordsLearnedFrom >= 500 {
            return "500 words — Tilde is beginning to recognize your patterns."
        }
        return nil
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }
}
