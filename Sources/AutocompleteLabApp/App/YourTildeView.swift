import SwiftUI

@MainActor
final class YourTildeViewModel: ObservableObject {
    @Published private(set) var snapshot = TildeProgressSnapshot(
        wordsWrittenWithTildeToday: 0,
        wordsWrittenWithTildeLifetime: 0,
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
            HStack(alignment: .center, spacing: 12) {
                Text(model.snapshot.wordsWrittenWithTildeToday.formatted())
                    .font(.system(size: 36, weight: .semibold))
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 1) {
                    Text("words today")
                        .font(.subheadline)
                    Text("\(model.snapshot.wordsWrittenWithTildeLifetime.formatted()) total")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.72))
                        .monospacedDigit()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(stageHeadline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if let stageSupportingText {
                    Text(stageSupportingText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let stageProgress {
                    ProgressView(value: stageProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)

                    Text(progressLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if let milestone = TildeProgressPresentation.milestoneText(for: model.snapshot) {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(milestone)
                }
                .font(.subheadline.weight(.medium))
            }
        }
    }

    private var stageHeadline: String {
        switch model.snapshot.personalizationStage {
        case .off: "Personalized suggestions are off"
        case .loading: "Loading your progress"
        case .unavailable: "Progress is unavailable"
        case let .learningWords(current, goal):
            "\(max(0, goal - current).formatted()) words until Tilde starts tuning to you"
        case let .buildingConfidence(days, goal):
            "\(max(0, goal - days)) writing days until your progress report"
        case .validating: "Checking your personalized predictions"
        case .tuned: "Tuned to you"
        }
    }

    private var stageSupportingText: String? {
        switch model.snapshot.personalizationStage {
        case .off:
            "Turn them on below to help Tilde adapt to your writing."
        case .loading:
            nil
        case .unavailable:
            "Tilde could not read learning progress. Your writing was not exposed."
        case .learningWords, .buildingConfidence:
            nil
        case .validating:
            "Keep writing normally while Tilde gathers enough evidence."
        case let .tuned(candidate, baseline):
            "Personalized predictions: \(percent(candidate)) vs \(percent(baseline)) without personalization."
        }
    }

    private var progressLabel: String {
        switch model.snapshot.personalizationStage {
        case let .learningWords(current, goal):
            "\(min(current, goal).formatted()) of \(goal.formatted()) words"
        case let .buildingConfidence(days, goal):
            "\(min(days, goal)) of \(goal) writing days"
        case .tuned:
            "Personalization ready"
        case .off, .loading, .unavailable, .validating:
            ""
        }
    }

    private var stageProgress: Double? {
        switch model.snapshot.personalizationStage {
        case .off, .loading, .unavailable, .validating: nil
        case let .learningWords(current, goal):
            goal > 0 ? min(1, Double(current) / Double(goal)) : 0
        case let .buildingConfidence(days, goal):
            goal > 0 ? min(1, Double(days) / Double(goal)) : 0
        case .tuned: 1
        }
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }
}

enum TildeProgressPresentation {
    static func milestoneText(for snapshot: TildeProgressSnapshot) -> String? {
        if snapshot.wordsLearnedFrom >= 2_000 {
            return "Learned from \(snapshot.wordsLearnedFrom.formatted()) words"
        }
        return nil
    }
}
