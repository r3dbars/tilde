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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(model.snapshot.wordsWrittenWithTildeToday.formatted())
                    .font(.system(size: 36, weight: .semibold))
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 1) {
                    Text("words written with Tilde today")
                        .font(.subheadline)
                    Text("\(model.snapshot.wordsWrittenWithTildeLifetime.formatted()) all time")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.72))
                        .monospacedDigit()
                }
            }

            if model.snapshot.personalSuggestionsToday > 0 {
                Text("\(model.snapshot.personalSuggestionsToday.formatted()) suggestions were personalized today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stageTitle)
                    .font(.headline)
                Text(stageDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let stageProgress {
                    HStack {
                        Text(progressStartLabel)
                        Spacer()
                        Text(progressEndLabel)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                    ProgressView(value: stageProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
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

            Text("Keep Tilde on and write normally. Every writing day makes it more personal.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
            "\(max(0, goal - current).formatted()) more words until Tilde starts checking whether personalization helps."
        case let .buildingConfidence(days, goal):
            "\(max(0, goal - days)) more writing days until Tilde can show whether it predicts you better."
        case .validating:
            "Tilde is checking whether personalized predictions are more accurate."
        case let .tuned(candidate, baseline):
            "Tilde now predicts your writing better than its general starting point: \(percent(candidate)) vs \(percent(baseline))."
        }
    }

    private var progressStartLabel: String {
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

    private var progressEndLabel: String {
        switch model.snapshot.personalizationStage {
        case let .learningWords(current, goal):
            "\(max(0, goal - current).formatted()) to go"
        case let .buildingConfidence(days, goal):
            "\(max(0, goal - days)) to go"
        case .tuned:
            "Complete"
        case .off, .loading, .unavailable, .validating:
            ""
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

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }
}

enum TildeProgressPresentation {
    static func milestoneText(for snapshot: TildeProgressSnapshot) -> String? {
        if snapshot.activeWritingDays >= 14 {
            return "14 writing days completed"
        }
        if snapshot.wordsLearnedFrom >= 2_000 {
            return "Learned from \(snapshot.wordsLearnedFrom.formatted()) words"
        }
        if snapshot.wordsLearnedFrom >= 500 {
            return "Learning from \(snapshot.wordsLearnedFrom.formatted()) words"
        }
        return nil
    }
}
