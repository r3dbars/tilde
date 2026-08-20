import AppKit
import SwiftUI

@MainActor
final class YourTildeWindowController: NSWindowController, NSWindowDelegate {
    private let model: YourTildeViewModel
    private var refreshTimer: Timer?

    init(
        personalHistory: PersonalHistoryController,
        openSettings: @escaping @MainActor () -> Void
    ) {
        model = YourTildeViewModel(personalHistory: personalHistory, openSettings: openSettings)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Your Tilde"
        window.contentViewController = NSHostingController(rootView: YourTildeView(model: model))
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show() {
        model.refresh()
        startRefreshing()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh() {
        guard window?.isVisible == true else { return }
        model.refresh()
    }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func startRefreshing() {
        guard refreshTimer == nil else { return }
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.model.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }
}

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
    private let openSettingsAction: @MainActor () -> Void
    private var refreshGeneration: UInt64 = 0

    init(
        personalHistory: PersonalHistoryController,
        openSettings: @escaping @MainActor () -> Void
    ) {
        self.personalHistory = personalHistory
        openSettingsAction = openSettings
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

    func openSettings() {
        openSettingsAction()
    }
}

private struct YourTildeView: View {
    @ObservedObject var model: YourTildeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "personalhotspot")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("Your Tilde")
                    .font(.title2.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 8) {
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

            Spacer(minLength: 0)

            HStack {
                Label("All learning stays on this Mac.", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Manage Learning") { model.openSettings() }
                    .buttonStyle(.link)
            }
        }
        .padding(24)
        .frame(width: 440, height: 420)
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
            "Turn on Personal Learning in Settings to help Tilde adapt to your writing."
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
