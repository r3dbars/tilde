import SwiftUI
import TildeLabKit

struct LabResearchView: View {
    @Bindable var store: LabWorkspaceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LabBenchHeader(
                    title: "Autoresearch",
                    subtitle: "Change one controlled knob, test it on the same quiz, keep improvements, discard regressions, and advance the champion.",
                    systemImage: "arrow.triangle.branch"
                )
                outcomeCard
                preflightCard
                campaignControls
                ledgerCard
            }
            .padding(24)
            .frame(maxWidth: 1_080, alignment: .leading)
        }
        .navigationTitle("Autoresearch")
    }

    private var outcomeCard: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 18) {
                Image(systemName: outcomeIcon)
                    .font(.system(size: 34))
                    .foregroundStyle(outcomeColor)
                    .frame(width: 48)
                VStack(alignment: .leading, spacing: 5) {
                    Text(outcomeTitle)
                        .font(.title2.weight(.bold))
                    Text(outcomeDetail)
                        .foregroundStyle(.secondary)
                    if let champion = store.researchChampion {
                        Text("Champion: \(champion.arm.id) · net savings \(percent(champion.metrics.netKeystrokeSavingsRate)) · \(champion.metrics.netKeystrokesSavedPer1000Characters.formatted(.number.precision(.fractionLength(1)))) / 1,000 chars · bad shows \(percent(champion.metrics.badSuggestionRate)) · P95 \(champion.metrics.latency.p95Milliseconds.map { "\($0) ms" } ?? "—")")
                            .font(.callout.monospacedDigit())
                    }
                }
                Spacer()
            }
            .padding(8)
        }
    }

    private var preflightCard: some View {
        GroupBox("Run environment") {
            HStack {
                Label(
                    store.powerPreflight.message,
                    systemImage: store.powerPreflight.isRecommended
                        ? "bolt.circle.fill"
                        : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(store.powerPreflight.isRecommended ? .green : .orange)
                Spacer()
                Text("Checked \(store.powerPreflight.checkedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Check again") { store.refreshPowerPreflight() }
            }
            .padding(8)
        }
    }

    private var campaignControls: some View {
        LabControlSection(
            "Campaign",
            detail: "The quiz, scorecard, model, and baseline are locked for the campaign. Trials mutate one setting at a time. Every completed trial is saved before the next one starts, so Pause and Resume do not lose work."
        ) {
            LabControlGrid {
                LabControlRow("Subsystem", help: "Keep each campaign scientifically legible by changing only one layer.") {
                    Picker("Subsystem", selection: Binding(
                        get: { store.researchConfiguration.subsystem ?? .all },
                        set: { store.researchConfiguration.subsystem = $0 }
                    )) {
                        ForEach(LabResearchSubsystem.allCases) { subsystem in
                            Text(subsystem.title).tag(subsystem)
                        }
                    }
                    .labelsHidden()
                }
                LabControlRow("Screening repeats") {
                    Stepper("\(store.researchConfiguration.screeningRepetitions)", value: $store.researchConfiguration.screeningRepetitions, in: 1...20)
                }
                LabControlRow("Confirmation repeats") {
                    Stepper("\(store.researchConfiguration.confirmationRepetitions)", value: $store.researchConfiguration.confirmationRepetitions, in: 2...100)
                }
                LabControlRow("Maximum mutations") {
                    Stepper("\(store.researchConfiguration.maximumTrials)", value: $store.researchConfiguration.maximumTrials, in: 1...LabResearchMutation.allCases.count)
                }
                LabControlRow("Control interval") {
                    Stepper("every \(store.researchConfiguration.controlInterval) trials", value: $store.researchConfiguration.controlInterval, in: 1...12)
                }
                LabControlRow("Protocol retries") {
                    Stepper("\(store.researchConfiguration.protocolRetryCount)", value: $store.researchConfiguration.protocolRetryCount, in: 0...5)
                }
                LabControlRow("Time budget") {
                    Stepper("\(store.researchConfiguration.timeBudgetMinutes) minutes", value: $store.researchConfiguration.timeBudgetMinutes, in: 15...720, step: 15)
                }
                LabControlRow("Controls") {
                    HStack(spacing: 18) {
                        Toggle("Randomize trial order", isOn: $store.researchConfiguration.randomizesTrialOrder)
                        Toggle("Restart workers between rounds", isOn: $store.researchConfiguration.restartsWorkersBetweenRounds)
                    }
                    .toggleStyle(.checkbox)
                }
            }
            HStack {
                Text("\(selectedMutationCount) bounded \((store.researchConfiguration.subsystem ?? .all).title.lowercased()) mutations · fixed local Gemma · Net Keystrokes Saved decides · no prompts or outputs persisted")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if store.isResearchRun {
                    Button("Pause after checkpoint", systemImage: "pause.fill") { store.pauseResearch() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Start 6-hour overnight", systemImage: "moon.stars.fill") {
                        store.startSixHourResearch()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!store.canStart)
                    Button(
                        store.activeCampaign?.state == .paused ? "Resume campaign" : "Start campaign",
                        systemImage: "play.fill"
                    ) { store.startResearch() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canStart)
                }
            }
        }
    }

    private var selectedMutationCount: Int {
        let subsystem = store.researchConfiguration.subsystem ?? .all
        return subsystem == .all
            ? LabResearchMutation.allCases.count
            : LabResearchMutation.allCases.count(where: { $0.subsystem == subsystem })
    }

    @ViewBuilder
    private var ledgerCard: some View {
        if let campaign = store.activeCampaign {
            GroupBox("Keep / discard ledger") {
                VStack(spacing: 0) {
                    HStack {
                        Text("State: \(campaign.state.rawValue.capitalized)")
                        Spacer()
                        Text("\(campaign.ledger.count) checkpoints")
                    }
                    .font(.callout.weight(.semibold))
                    .padding(8)
                    Divider()
                    ForEach(campaign.ledger.reversed()) { entry in
                        HStack(spacing: 10) {
                            Image(systemName: decisionIcon(entry.decision))
                                .foregroundStyle(decisionColor(entry.decision))
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.mutation?.title ?? entry.decision.rawValue.capitalized)
                                Text(entry.armID)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.verdict.title)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text(entry.decision.rawValue.uppercased())
                                .font(.caption.monospaced().weight(.bold))
                                .frame(width: 92, alignment: .trailing)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 8)
                        Divider()
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No research campaign yet",
                systemImage: "arrow.triangle.branch",
                description: Text("Start from the currently selected Reply Quality arm.")
            )
        }
    }

    private var outcomeTitle: String {
        guard let champion = store.researchChampion else { return "No winner yet" }
        return champion.verdict == .eligible ? "Eligible winner" : "No winner yet"
    }

    private var outcomeDetail: String {
        store.researchChampion?.plainEnglishOutcome
            ?? "Run a campaign to establish a baseline, test bounded mutations, and keep only genuine improvements."
    }

    private var outcomeIcon: String {
        store.researchChampion?.verdict == .eligible ? "checkmark.seal.fill" : "flag.checkered"
    }

    private var outcomeColor: Color {
        store.researchChampion?.verdict == .eligible ? .green : .secondary
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }

    private func decisionIcon(_ decision: LabResearchDecision) -> String {
        switch decision {
        case .keep, .confirmation: "checkmark.circle.fill"
        case .discard: "xmark.circle.fill"
        case .baseline, .control: "scope"
        case .retry: "arrow.clockwise.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private func decisionColor(_ decision: LabResearchDecision) -> Color {
        switch decision {
        case .keep, .confirmation: .green
        case .discard, .failed: .red
        case .baseline, .control: .blue
        case .retry: .orange
        }
    }
}
