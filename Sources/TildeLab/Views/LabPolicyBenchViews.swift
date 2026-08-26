import SwiftUI
import TildeLabKit

struct LabJudgmentBenchView: View {
    @Bindable var store: LabWorkspaceStore

    private var arm: Binding<LabArmConfiguration> {
        Binding(get: { store.selectedArm }, set: { store.selectedArm = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LabBenchHeader(
                    title: "Judgment",
                    subtitle: "Separate model ability from Tilde's decision to show, trim, or suppress a candidate.",
                    systemImage: LabBenchKind.judgment.systemImage
                )
                LabArmBar(store: store)
                LabJudgmentEditor(arm: arm)
                LabScoringEditor(arm: arm)
                LabDecisionLegend()
                LabSyntheticAuditCard(store: store, bench: .judgment)
                LabHardGateBanner()
                LabRunActionCard(store: store)
            }
            .padding(24)
            .frame(maxWidth: 1_120, alignment: .leading)
        }
        .navigationTitle("Judgment")
    }
}

private struct LabJudgmentEditor: View {
    @Binding var arm: LabArmConfiguration

    var body: some View {
        LabControlSection(
            "Output policy",
            detail: "Production keeps every cleaner defense on. Diagnostic mode is the only preset that honors individual ablation checkboxes; unsafe hidden/control characters remain a hard rejection in every mode."
        ) {
            LabControlGrid {
                LabControlRow("Cleaner recipe") {
                    LabEnumPicker(label: "Cleaner", selection: $arm.judgment.cleanerPreset)
                }
                LabControlRow("Visible limits") {
                    HStack {
                        Stepper("\(arm.judgment.maximumVisibleWords) words", value: $arm.judgment.maximumVisibleWords, in: 1...20)
                        Stepper("\(arm.judgment.maximumVisibleCharacters) characters", value: $arm.judgment.maximumVisibleCharacters, in: 1...1_000)
                    }
                }
                LabControlRow("Length policy", help: "Confidence-based length stays silent below its floor, then expands from a short phrase to a clause or full sentence as evidence improves.") {
                    LabEnumPicker(label: "Length", selection: $arm.judgment.lengthPolicy)
                }
                if arm.judgment.lengthPolicy == .confidenceBased {
                    LabControlRow("Confidence bands") {
                        VStack(alignment: .leading) {
                            LabValueSlider(value: $arm.judgment.dynamicLength.silenceBelowConfidence, range: 0...1, step: 0.01)
                            Text("silence below \(arm.judgment.dynamicLength.silenceBelowConfidence.formatted(.percent.precision(.fractionLength(0))))")
                                .font(.caption).foregroundStyle(.secondary)
                            LabValueSlider(value: $arm.judgment.dynamicLength.highConfidence, range: 0...1, step: 0.01)
                            LabValueSlider(value: $arm.judgment.dynamicLength.veryHighConfidence, range: 0...1, step: 0.01)
                        }
                    }
                    LabControlRow("Dynamic caps") {
                        HStack {
                            Stepper("\(arm.judgment.dynamicLength.shortMaximumWords) short", value: $arm.judgment.dynamicLength.shortMaximumWords, in: 1...20)
                            Stepper("\(arm.judgment.dynamicLength.clauseMaximumWords) clause", value: $arm.judgment.dynamicLength.clauseMaximumWords, in: 1...20)
                            Stepper("\(arm.judgment.dynamicLength.sentenceMaximumWords) sentence", value: $arm.judgment.dynamicLength.sentenceMaximumWords, in: 1...20)
                        }
                    }
                }
                LabControlRow("Scene echo") {
                    HStack {
                        Toggle("Reject", isOn: $arm.judgment.rejectsSceneEcho)
                            .toggleStyle(.checkbox)
                        Stepper("\(arm.judgment.sceneEchoMinimumWords) words", value: $arm.judgment.sceneEchoMinimumWords, in: 1...20)
                        Stepper("\(arm.judgment.sceneEchoMinimumCharacters) chars", value: $arm.judgment.sceneEchoMinimumCharacters, in: 1...500)
                    }
                }
                LabControlRow("Factual grounding", help: "Rejects newly invented names, numbers, dates, times, and—in the broadest mode—long factual anchors absent from typed or scene context.") {
                    LabEnumPicker(label: "Grounding", selection: $arm.judgment.factualGrounding)
                }
                LabControlRow("Sensitive scenes") {
                    Toggle("Apply production silence gate", isOn: $arm.judgment.suppressesSensitiveScenes)
                        .toggleStyle(.checkbox)
                }
                LabControlRow("Dangling tail") {
                    Toggle("Repair trailing function words", isOn: $arm.judgment.repairsDanglingTail)
                        .toggleStyle(.checkbox)
                }
            }

            DisclosureGroup("Diagnostic cleaner ablations") {
                VStack(alignment: .leading, spacing: 9) {
                    Toggle("Reject prompt/instruction echoes", isOn: $arm.judgment.rejectsPromptLeaks)
                    Toggle("Reject typed-context replay", isOn: $arm.judgment.rejectsContextReplay)
                    Toggle("Trim self-repetition", isOn: $arm.judgment.rejectsSelfRepetition)
                    Text("These switches are intentionally ignored by Production and Strict recipes. They exist to measure which defense caused a loss, not to weaken shipping safety by accident.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)
                .padding(.top, 8)
            }
        }
    }
}

private struct LabScoringEditor: View {
    @Binding var arm: LabArmConfiguration

    var body: some View {
        LabControlSection(
            "Goal metric",
            detail: "Net Keystrokes Saved is the locked headline. The old weighted score remains diagnostic only. Safety, bad suggestions, temporal integrity, privacy, interaction, and latency stay outside the number."
        ) {
            LabControlGrid {
                LabControlRow("Policy version") {
                    TextField(LabGoalContract.identifier, text: $arm.scoring.policyVersion)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                        .disabled(arm.scoring.usesGoalContract)
                }
                LabControlRow("Usefulness") {
                    LabValueSlider(value: $arm.scoring.usefulnessWeight, range: 0...1, step: 0.05)
                        .disabled(arm.scoring.usesScorecardV3 || arm.scoring.usesGoalContract)
                }
                LabControlRow("Restraint") {
                    LabValueSlider(value: $arm.scoring.restraintWeight, range: 0...1, step: 0.05)
                        .disabled(arm.scoring.usesScorecardV3 || arm.scoring.usesGoalContract)
                }
                LabControlRow("Factuality") {
                    LabValueSlider(value: $arm.scoring.factualityWeight, range: 0...1, step: 0.05)
                        .disabled(arm.scoring.usesScorecardV3 || arm.scoring.usesGoalContract)
                }
                LabControlRow("Brevity") {
                    LabValueSlider(value: $arm.scoring.brevityWeight, range: 0...1, step: 0.05)
                        .disabled(arm.scoring.usesScorecardV3 || arm.scoring.usesGoalContract)
                }
                LabControlRow("Comparisons") {
                    Toggle("Lock weights across arms", isOn: $arm.scoring.weightsLockedDuringComparison)
                        .toggleStyle(.checkbox)
                }
            }
        }
    }
}

private struct LabDecisionLegend: View {
    var body: some View {
        LabControlSection(
            "Loss accounting",
            detail: "Every case records one privacy-safe decision reason, so a low score identifies the layer that lost the opportunity."
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), alignment: .leading, spacing: 8) {
                ForEach(LabDecisionReason.allCases, id: \.rawValue) { reason in
                    Label(reason.rawValue, systemImage: icon(reason))
                        .font(.callout.monospaced())
                        .foregroundStyle(reason == .shown ? .green : .secondary)
                }
            }
        }
    }

    private func icon(_ reason: LabDecisionReason) -> String {
        switch reason {
        case .shown: "checkmark.circle.fill"
        case .timeout, .protocolError: "exclamationmark.triangle.fill"
        case .sensitiveScene: "lock.shield.fill"
        default: "minus.circle"
        }
    }
}

struct LabSceneMemoryBenchView: View {
    @Bindable var store: LabWorkspaceStore

    private var arm: Binding<LabArmConfiguration> {
        Binding(get: { store.selectedArm }, set: { store.selectedArm = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LabBenchHeader(
                    title: "Scene Memory",
                    subtitle: "Stress synthetic AX/OCR evidence, conversation geometry, freshness, capture cadence, and context corruption.",
                    systemImage: LabBenchKind.sceneMemory.systemImage
                )
                LabArmBar(store: store)
                LabSceneSourceEditor(arm: arm)
                LabSceneClassifierEditor(arm: arm)
                LabCaptureEditor(arm: arm)
                LabSyntheticAuditCard(store: store, bench: .sceneMemory)
                LabHardGateBanner()
            }
            .padding(24)
            .frame(maxWidth: 1_120, alignment: .leading)
        }
        .navigationTitle("Scene Memory")
    }
}

private struct LabSceneSourceEditor: View {
    @Binding var arm: LabArmConfiguration

    var body: some View {
        LabControlSection(
            "Capture source and OCR",
            detail: "AX is exact when available; OCR is the bounded fallback. Noise injection applies only to synthetic fixtures."
        ) {
            LabControlGrid {
                LabControlRow("Source") {
                    LabEnumPicker(label: "Source", selection: $arm.sceneBench.captureSource)
                }
                LabControlRow("OCR mode") {
                    LabEnumPicker(label: "OCR mode", selection: $arm.sceneBench.recognitionMode)
                }
                LabControlRow("Language correction") {
                    Toggle("Enable Vision correction", isOn: $arm.sceneBench.usesLanguageCorrection)
                        .toggleStyle(.checkbox)
                }
                LabControlRow("Synthetic OCR noise") {
                    HStack {
                        Toggle("Inject", isOn: $arm.sceneBench.injectsOCRNoise)
                            .toggleStyle(.checkbox)
                        LabValueSlider(value: $arm.sceneBench.ocrNoiseRate, range: 0...1, step: 0.01)
                    }
                }
                LabControlRow("Adversarial text") {
                    Toggle("Include screen prompt injection", isOn: $arm.sceneBench.testsPromptInjection)
                        .toggleStyle(.checkbox)
                }
            }
        }
    }
}

private struct LabSceneClassifierEditor: View {
    @Binding var arm: LabArmConfiguration

    var body: some View {
        LabControlSection(
            "Conversation classifier",
            detail: "These are the geometry and bounded-memory hypotheses used by synthetic Scene fixtures. Production defaults are shown initially."
        ) {
            LabControlGrid {
                LabControlRow("Freshness") {
                    LabValueSlider(value: $arm.sceneBench.freshnessSeconds, range: 0...300, step: 1, fractionDigits: 0, suffix: " s")
                }
                LabControlRow("Turn bounds") {
                    HStack {
                        Stepper("\(arm.sceneBench.maximumTurns) turns", value: $arm.sceneBench.maximumTurns, in: 1...100)
                        Stepper("\(arm.sceneBench.maximumTurnCharacters.formatted()) chars", value: $arm.sceneBench.maximumTurnCharacters, in: 1...24_000, step: 100)
                    }
                }
                LabControlRow("Reference bound") {
                    Stepper("\(arm.sceneBench.maximumReferenceCharacters.formatted()) chars", value: $arm.sceneBench.maximumReferenceCharacters, in: 1...24_000, step: 100)
                }
                LabControlRow("Bubble width") {
                    HStack {
                        LabValueSlider(value: $arm.sceneBench.bubbleMinimumWidth, range: 0...1, step: 0.01)
                        Text("to")
                        LabValueSlider(value: $arm.sceneBench.bubbleMaximumWidth, range: 0...1, step: 0.01)
                    }
                }
                LabControlRow("Vertical bands") {
                    Stepper("\(arm.sceneBench.verticalBandCount)", value: $arm.sceneBench.verticalBandCount, in: 2...100)
                }
                LabControlRow("Speaker buckets") {
                    HStack {
                        Text("other ≤")
                        LabValueSlider(value: $arm.sceneBench.otherSpeakerMaximumX, range: 0...1, step: 0.01)
                        Text("self ≥")
                        LabValueSlider(value: $arm.sceneBench.selfSpeakerMinimumX, range: 0...1, step: 0.01)
                    }
                }
                LabControlRow("Wrapped-line gap") {
                    LabValueSlider(value: $arm.sceneBench.wrappedLineGapRatio, range: 0...3, step: 0.05)
                }
                LabControlRow("Reference word floor") {
                    Stepper("\(arm.sceneBench.rareReferenceMinimumLength) characters", value: $arm.sceneBench.rareReferenceMinimumLength, in: 1...32)
                }
                LabControlRow("Dedupe floor") {
                    Stepper("\(arm.sceneBench.dedupeMinimumLength) characters", value: $arm.sceneBench.dedupeMinimumLength, in: 1...64)
                }
            }
        }
    }
}

private struct LabCaptureEditor: View {
    @Binding var arm: LabArmConfiguration

    var body: some View {
        LabControlSection(
            "Capture timing and change detection",
            detail: "Use these to trade freshness, energy, OCR work, and stability in synthetic capture traces."
        ) {
            LabControlGrid {
                LabControlRow("Typing pause") {
                    LabValueSlider(value: $arm.sceneBench.typingPauseSeconds, range: 0...5, step: 0.05, suffix: " s")
                }
                LabControlRow("Cadence cap") {
                    LabValueSlider(value: $arm.sceneBench.cadenceSeconds, range: 0.1...30, step: 0.1, suffix: " s")
                }
                LabControlRow("Change floor") {
                    LabValueSlider(value: $arm.sceneBench.changeCadenceFloorSeconds, range: 0...10, step: 0.05, suffix: " s")
                }
                LabControlRow("Activity window") {
                    LabValueSlider(value: $arm.sceneBench.activityWindowSeconds, range: 0...120, step: 1, fractionDigits: 0, suffix: " s")
                }
                LabControlRow("Luminance grid") {
                    HStack {
                        Stepper("\(arm.sceneBench.gridWidth) wide", value: $arm.sceneBench.gridWidth, in: 1...256)
                        Stepper("\(arm.sceneBench.gridHeight) high", value: $arm.sceneBench.gridHeight, in: 1...256)
                    }
                }
                LabControlRow("Tile threshold") {
                    LabValueSlider(value: $arm.sceneBench.tileChangeThreshold, range: 0...1, step: 0.005, fractionDigits: 3)
                }
                LabControlRow("Full-frame threshold") {
                    LabValueSlider(value: $arm.sceneBench.fullFrameChangeFraction, range: 0...1, step: 0.01)
                }
                LabControlRow("Region padding") {
                    Stepper("\(arm.sceneBench.regionPaddingTiles) tiles", value: $arm.sceneBench.regionPaddingTiles, in: 0...20)
                }
            }
        }
    }
}

struct LabPersonalizationBenchView: View {
    @Bindable var store: LabWorkspaceStore

    private var arm: Binding<LabArmConfiguration> {
        Binding(get: { store.selectedArm }, set: { store.selectedArm = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LabBenchHeader(
                    title: "Personalization",
                    subtitle: "Measure whether synthetic local history adds recognition without overriding restraint or scene facts.",
                    systemImage: LabBenchKind.personalization.systemImage
                )
                LabArmBar(store: store)
                LabPersonalizationEditor(arm: arm)
                LabSyntheticAuditCard(store: store, bench: .personalization)
                LabHardGateBanner()
            }
            .padding(24)
            .frame(maxWidth: 1_120, alignment: .leading)
        }
        .navigationTitle("Personalization")
    }
}

private struct LabPersonalizationEditor: View {
    @Binding var arm: LabArmConfiguration

    var body: some View {
        LabControlSection(
            "Synthetic Personal History",
            detail: "This bench is synthetic-only. It never imports or exports the owner's real writing, and no arm may override base silence."
        ) {
            LabControlGrid {
                LabControlRow("Personalization") {
                    Toggle("Enable synthetic candidate", isOn: $arm.personalization.enabled)
                        .toggleStyle(.checkbox)
                }
                LabControlRow("Minimum support") {
                    Stepper("\(arm.personalization.minimumSupport) observations", value: $arm.personalization.minimumSupport, in: 1...100)
                }
                LabControlRow("Minimum confidence") {
                    LabValueSlider(value: $arm.personalization.minimumConfidence, range: 0...1, step: 0.01)
                }
                LabControlRow("Personal tail") {
                    Stepper("\(arm.personalization.maximumTailWords) words", value: $arm.personalization.maximumTailWords, in: 1...20)
                }
                LabControlRow("Recency weight") {
                    LabValueSlider(value: $arm.personalization.recencyWeight, range: 0...1, step: 0.05)
                }
                LabControlRow("Frequency weight") {
                    LabValueSlider(value: $arm.personalization.frequencyWeight, range: 0...1, step: 0.05)
                }
                LabControlRow("History scope") {
                    LabEnumPicker(label: "Scope", selection: $arm.personalization.scope)
                }
                LabControlRow("Arbitration") {
                    LabEnumPicker(label: "Arbitration", selection: $arm.personalization.arbitration)
                }
                LabControlRow("Lookup deadline") {
                    Stepper("\(arm.personalization.lookupDeadlineMilliseconds) ms", value: $arm.personalization.lookupDeadlineMilliseconds, in: 1...10_000)
                }
            }
            Divider()
            HStack(spacing: 20) {
                Toggle("Stale history", isOn: $arm.personalization.includesStaleHistoryCases)
                Toggle("Contradictory history", isOn: $arm.personalization.includesContradictoryHistoryCases)
                Toggle("Poisoned history", isOn: $arm.personalization.includesPoisonedHistoryCases)
            }
            .toggleStyle(.checkbox)
            Label("Base silence override is permanently disabled.", systemImage: "lock.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
