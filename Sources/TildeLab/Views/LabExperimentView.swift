import SwiftUI
import TildeLabKit
import UniformTypeIdentifiers

struct LabExperimentView: View {
    @Bindable var store: LabWorkspaceStore
    @State private var importingSuite = false
    @State private var importingManifest = false

    private var arm: Binding<LabArmConfiguration> {
        Binding(get: { store.selectedArm }, set: { store.selectedArm = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LabBenchHeader(
                    title: "Reply Quality",
                    subtitle: LabGoalContract.mission,
                    systemImage: LabBenchKind.reply.systemImage
                )
                goalContract
                modelQualitySetup
                if store.isCertifiedCorpusLoaded {
                    LabCorpusQualityCard(store: store)
                }
                LabArmBar(store: store)
                LabReplyOverview(store: store)
                LabScenarioEditor(arm: arm, store: store)
                LabGenerationEditor(arm: arm)
                LabPromptEditor(arm: arm)
                LabSyntheticAuditCard(store: store, bench: .reply)
                LabHardGateBanner()
                LabRunActionCard(store: store)
            }
            .padding(24)
            .frame(maxWidth: 1_120, alignment: .leading)
        }
        .navigationTitle("Reply Quality")
        .toolbar { toolbar }
        .fileImporter(
            isPresented: $importingSuite,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first { store.importSuite(from: url) }
        }
        .fileImporter(
            isPresented: $importingManifest,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first { store.importManifest(from: url) }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button("Reports", systemImage: "folder") { store.revealReportsFolder() }
            Menu("Quiz", systemImage: "checklist") {
                Button("Certified Corpus V2 · 1,000 situations") {
                    store.loadCertifiedCorpus()
                }
                Button("Experimental Corpus Pilot V1 · 1,000 situations") {
                    store.loadCorpusPilot()
                }
                Divider()
                Button(LabBuiltInSuite.slackReplyGoldV1.title) {
                    store.loadBuiltInSuite(.slackReplyGoldV1)
                }
                Button(LabBuiltInSuite.replyingV2.title) {
                    store.loadBuiltInSuite(.replyingV2)
                }
                Button(LabBuiltInSuite.replyingV1.title) {
                    store.loadBuiltInSuite(.replyingV1)
                }
                Divider()
                Button("Mixed Learning · 60% real / 40% synthetic") {
                    store.loadMixedLearningSuite()
                }
                Button("Private Personal Replay · development only") {
                    store.loadPrivateHistoricalReplay()
                }
            }
            Menu("Import", systemImage: "square.and.arrow.down") {
                Button("Scenario Suite…") { importingSuite = true }
                Button("Experiment Manifest…") { importingManifest = true }
            }
            Button("Export", systemImage: "square.and.arrow.up") { store.exportManifest() }
            Button("Run", systemImage: "play.fill") { store.startRun() }
                .disabled(!store.canStart)
        }
    }

    private var goalContract: some View {
        GroupBox("Locked Goal Contract") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Maximize human-acceptable continuations and actual typing saved. Exact recorded text earns keystroke credit; reviewed alternative wording earns quality credit without pretending it was the user's recorded future.")
                    .font(.headline)
                Text("Bad suggestions, sensitive situations, temporal integrity, privacy, interaction integrity, and p95 latency remain separate gates. A campaign cannot tune them away.")
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    private var modelQualitySetup: some View {
        LabControlSection(
            "Model quality shootout",
            detail: "This deliberately removes the when-to-speak question. Both models get the same 50 development situations where Tilde should speak, temperature 0, production prompt, and 3-word cap. Human-acceptable output decides the winner; speed is recorded only as a diagnostic."
        ) {
            HStack(spacing: 12) {
                Button("1 · Prepare E2B Baseline", systemImage: "1.circle.fill") {
                    store.prepareProductionModelQualityBaseline()
                }
                .buttonStyle(.borderedProminent)
                Button("2 · Prepare 26B Candidate", systemImage: "2.circle.fill") {
                    store.prepareGemma26BModelQualityCandidate()
                }
                .buttonStyle(.borderedProminent)
                Button("3 · Run Frontier Ceiling", systemImage: "sparkles") {
                    store.startFrontierQualityCeiling()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canStartFrontierQualityCeiling)
                Text("Run E2B, run 26B, then use Sol as the ceiling.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LabControlGrid {
                LabControlRow("Model mode") {
                    LabEnumPicker(label: "Model mode", selection: $store.modelVerificationMode)
                }
                LabControlRow("Local GGUF") {
                    HStack {
                        TextField("Model path", text: $store.modelPath)
                            .textFieldStyle(.roundedBorder)
                        if store.modelVerificationMode == .experimentalLocal {
                            Button("Choose…") { store.chooseExperimentalModel() }
                        }
                    }
                }
                if store.modelVerificationMode == .experimentalLocal {
                    LabControlRow("Model identity") {
                        HStack {
                            TextField("organization/model", text: $store.experimentalModelIdentifier)
                                .textFieldStyle(.roundedBorder)
                            TextField("revision", text: $store.experimentalModelRevision)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 180)
                        }
                    }
                }
                LabControlRow("Ready") {
                    Label(
                        store.selectedModelIsInstalled ? "Local model found" : "Model file not installed yet",
                        systemImage: store.selectedModelIsInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(store.selectedModelIsInstalled ? .green : .orange)
                }
            }

            if store.modelVerificationMode == .experimentalLocal {
                Text("Experimental means Lab-only: the GGUF is format-checked, hashed into the report, and never accepted as Tilde's production asset. Model downloads are intentionally not performed by Tilde Lab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Label("Frontier: \(store.frontierModel)", systemImage: "cloud.fill")
                    .font(.callout.weight(.semibold))
                Text("Uses two batched Codex subscription messages. Only project-owned synthetic prompts are permitted; private replay is rejected before launch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LabCorpusQualityCard: View {
    @Bindable var store: LabWorkspaceStore

    private var quality: LabCorpusQualityReport? { store.corpusQualityReport }
    private var certificate: LabCorpusModelCertificate? { store.corpusModelCertificate }

    var body: some View {
        LabControlSection(
            "Corpus trust gate",
            detail: "This answers one question: is the quiz safe to use for automated optimization? The detailed evidence remains available, but these trust lines are the decision."
        ) {
            if let quality {
                VStack(spacing: 0) {
                    gateRow(
                        "Corpus construction",
                        status: quality.passesStaticGate ? .pass : .fail,
                        detail: "\(quality.rootCount) unique situations · \(quality.positiveCount) speak · \(quality.silenceCount) silence · \(quality.categoryFamilyCount) behavior families"
                    )
                    Divider()
                    let multiAnswer = quality.checks.first { $0.id == "multi-answer" }
                    gateRow(
                        "Human-acceptable answers",
                        status: gateStatus(multiAnswer?.status),
                        detail: multiAnswer?.detail ?? "Accepted answer coverage has not been audited."
                    )
                    Divider()
                    let review = quality.checks.first { $0.id == "review" }
                    gateRow(
                        "Structured review sample",
                        status: gateStatus(review?.status),
                        detail: review?.detail ?? "The locked 100-case sample has not been reviewed."
                    )
                    Divider()
                    gateRow(
                        "Does context actually help?",
                        status: contextStatus,
                        detail: contextDetail
                    )
                    Divider()
                    gateRow(
                        "Locked holdout",
                        status: holdoutStatus,
                        detail: holdoutDetail
                    )
                    Divider()
                    gateRow(
                        "Real-world evidence",
                        status: .pending,
                        detail: "Not claimed by this synthetic corpus. Private temporal replay and foreground dogfooding remain separate proof."
                    )
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(overallTitle)
                            .font(.headline)
                            .foregroundStyle(overallColor)
                        Text(overallDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Run Quick 8 Test", systemImage: "hare.fill") {
                        store.startQuickCertifiedExperiment()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canStartQuickCertifiedExperiment)
                    Button(
                        certificate == nil ? "Run 3,000-Case Certification" : "Rerun Certification",
                        systemImage: "checkmark.shield"
                    ) {
                        store.startCorpusCertification()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canStartCorpusCertification)
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func gateRow(
        _ title: String,
        status: LabCorpusGateStatus,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status.icon)
                .foregroundStyle(status.color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var contextStatus: LabCorpusGateStatus {
        guard let certificate else { return .pending }
        return certificate.passes ? .pass : .fail
    }

    private var contextDetail: String {
        guard let certificate else {
            return "Not tested yet. Certification compares correct context with typed-only and intentionally wrong context."
        }
        if certificate.passes {
            return "Passed: \(percent(certificate.correctContext.usefulnessRate)) human-acceptable with correct context vs \(percent(certificate.wrongContext.usefulnessRate)) with wrong context and \(percent(certificate.typedOnly.usefulnessRate)) with typed text only."
        }
        return "Failed \(certificate.failures.count) context check\(certificate.failures.count == 1 ? "" : "s"). Do not optimize against this corpus yet."
    }

    private var holdoutStatus: LabCorpusGateStatus {
        guard let holdout = certificate?.partitions.first(where: { $0.partition == .holdout }) else {
            return .pending
        }
        return holdout.correctContextWins ? .pass : .fail
    }

    private var holdoutDetail: String {
        guard let holdout = certificate?.partitions.first(where: { $0.partition == .holdout }) else {
            return "200 situations are sealed from tuning and await the context-control test."
        }
        return holdout.correctContextWins
            ? "Passed: correct context also wins on all 200 untouched holdout situations."
            : "Failed: correct context did not win on the untouched holdout."
    }

    private var overallTitle: String {
        if quality?.passesStaticGate != true { return "Not trustworthy" }
        if certificate?.passes == true { return "Corpus certified" }
        if certificate == nil { return "Static checks passed · model proof needed" }
        return "Certification failed"
    }

    private var overallDetail: String {
        certificate?.passes == true
            ? "The quiz is safe for development autoresearch. Current Tilde baseline: \(percent(certificate?.correctContext.usefulnessRate ?? 0)) human-acceptable and \(percent(certificate?.correctContext.netKeystrokeSavingsRate ?? 0)) net typing saved; the corpus passed, but output quality still needs work."
            : "Tilde Lab will block autoresearch on this corpus until the model certificate passes."
    }

    private var overallColor: Color {
        certificate?.passes == true ? .green : (certificate == nil ? .orange : .red)
    }

    private func gateStatus(_ status: TildeLabKit.LabCorpusCheckStatus?) -> LabCorpusGateStatus {
        switch status {
        case .pass: .pass
        case .fail: .fail
        case .pending, .none: .pending
        }
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }
}

private enum LabCorpusGateStatus {
    case pass
    case fail
    case pending

    var icon: String {
        switch self {
        case .pass: "checkmark.circle.fill"
        case .fail: "xmark.circle.fill"
        case .pending: "clock.fill"
        }
    }

    var color: Color {
        switch self {
        case .pass: .green
        case .fail: .red
        case .pending: .orange
        }
    }
}

private struct LabReplyOverview: View {
    @Bindable var store: LabWorkspaceStore

    var body: some View {
        LabControlSection(
            "Experiment loop",
            detail: "Each arm uses the same selected fixture partition and worker pool. Reports retain the full knob manifest, aggregate outcomes, reason codes, and timings—never prompts or model text."
        ) {
            HStack(spacing: 14) {
                LabSummaryTile("Suite", store.suite?.name ?? "Unavailable", "local evaluation input")
                LabSummaryTile("Distinct situations", store.selectedDistinctRootCount.formatted(), "actual evidence")
                LabSummaryTile("Evaluations / arm", store.selectedArmEvaluations.formatted(), "including repetitions")
                LabSummaryTile("Concurrency", store.effectiveConcurrency.formatted(), "worker slots")
            }
            if store.isLoadingSuite {
                Label("Normalizing the local corpus…", systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let suite = store.suite {
                let historical = suite.scenarios.count(where: { $0.evaluation.source.isHistorical })
                let protected = suite.scenarios.count(where: { $0.partition == .validation || $0.partition == .holdout })
                let corpusCounts = Dictionary(grouping: suite.scenarios) {
                    $0.evaluation.corpusID ?? "unregistered"
                }.mapValues { scenarios in
                    Set(scenarios.map { $0.evaluation.rootScenarioID ?? $0.id }).count
                }
                let corpusSummary = corpusCounts.keys.sorted().map {
                    "\(corpusCounts[$0, default: 0]) \($0)"
                }.joined(separator: " · ")
                Text("\(historical.formatted()) private historical · \(protected.formatted()) protected validation/holdout · \(Set(suite.scenarios.map(\.evaluation.contextVariant)).count) context variants")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if !corpusSummary.isEmpty {
                    Text(corpusSummary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if let history = store.historicalReplaySummary {
                Text("Loaded privately in memory: \(history.acceptedCases) accepted events · \(history.typedInsteadCases) typed-instead events · \(history.screenContextCases) with recorded screen text. Development-only until temporal integrity can be proven.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LabScenarioEditor: View {
    @Binding var arm: LabArmConfiguration
    @Bindable var store: LabWorkspaceStore

    var body: some View {
        LabControlSection(
            "Situations and coverage",
            detail: "Repetitions measure latency and stochastic stability. Distinct scenarios create behavioral coverage. Tagged JSON suites can use every filter below."
        ) {
            LabControlGrid {
                LabControlRow("Arm ID", help: "Stable label for this exact candidate configuration.") {
                    TextField("candidate-v1", text: $arm.id)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                }
                LabControlRow("Partition", help: "Keep development tuning separate from locked validation, permanent regressions, and adversarial cases.") {
                    LabEnumPicker(label: "Partition", selection: $arm.scenarios.partition)
                }
                LabControlRow("Opportunity", help: "Use Should speak only to compare wording quality without mixing in the separate when-to-speak decision.") {
                    LabEnumPicker(label: "Opportunity", selection: suggestionExpectation)
                }
                LabControlRow("Situation cap", help: "A deterministic cap on distinct situation roots. Zero means use every eligible situation.") {
                    Stepper(
                        maximumSituations.wrappedValue == 0
                            ? "All eligible"
                            : maximumSituations.wrappedValue.formatted(),
                        value: maximumSituations,
                        in: 0...10_000,
                        step: 50
                    )
                }
                LabControlRow("Languages") {
                    TextField("en, es", text: languages)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                }
                LabControlRow("Registers") {
                    HStack(spacing: 18) {
                        Toggle("Chat", isOn: $arm.scenarios.includesChat)
                        Toggle("Email", isOn: $arm.scenarios.includesEmail)
                        Toggle("Prose", isOn: $arm.scenarios.includesProse)
                    }
                    .toggleStyle(.checkbox)
                }
            }

            Divider()
            Text("Reply intents").font(.callout.weight(.semibold))
            LabToggleCloud(selection: $arm.scenarios.intents)
            Text("Tone").font(.callout.weight(.semibold))
            LabToggleCloud(selection: $arm.scenarios.tones)

            DisclosureGroup("Coverage dimensions") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), alignment: .leading) {
                    Toggle("Mid-word", isOn: $arm.scenarios.includesMidWord)
                    Toggle("Word boundary", isOn: $arm.scenarios.includesWordBoundary)
                    Toggle("Typos and casing", isOn: $arm.scenarios.includesTypos)
                    Toggle("Long context", isOn: $arm.scenarios.includesLongContext)
                    Toggle("Ambiguity", isOn: $arm.scenarios.includesAmbiguity)
                    Toggle("Multiple questions", isOn: $arm.scenarios.includesMultipleQuestions)
                    Toggle("Contradictions", isOn: $arm.scenarios.includesContradictions)
                    Toggle("Stale context", isOn: $arm.scenarios.includesStaleContext)
                    Toggle("Irrelevant context", isOn: $arm.scenarios.includesIrrelevantContext)
                    Toggle("Names", isOn: $arm.scenarios.includesNames)
                    Toggle("Dates", isOn: $arm.scenarios.includesDates)
                    Toggle("Times", isOn: $arm.scenarios.includesTimes)
                    Toggle("Locations", isOn: $arm.scenarios.includesLocations)
                    Toggle("Quantities", isOn: $arm.scenarios.includesQuantities)
                    Toggle("Deadlines", isOn: $arm.scenarios.includesDeadlines)
                    Toggle("Sensitive", isOn: $arm.scenarios.includesSensitiveCases)
                    Toggle("Sensitive near-miss", isOn: $arm.scenarios.includesSensitiveNearMisses)
                    Toggle("Prompt injection", isOn: $arm.scenarios.includesPromptInjection)
                    Toggle("Counterfactual pairs", isOn: $arm.scenarios.includesCounterfactualPairs)
                }
                .toggleStyle(.checkbox)
                .padding(.top, 8)
            }
        }
    }

    private var languages: Binding<String> {
        Binding(
            get: { arm.scenarios.languages.joined(separator: ", ") },
            set: { value in
                arm.scenarios.languages = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private var suggestionExpectation: Binding<LabSuggestionExpectationFilter> {
        Binding(
            get: { arm.scenarios.suggestionExpectation ?? .all },
            set: { arm.scenarios.suggestionExpectation = $0 == .all ? nil : $0 }
        )
    }

    private var maximumSituations: Binding<Int> {
        Binding(
            get: { arm.scenarios.maximumDistinctSituations ?? 0 },
            set: { arm.scenarios.maximumDistinctSituations = $0 == 0 ? nil : $0 }
        )
    }
}

private struct LabGenerationEditor: View {
    @Binding var arm: LabArmConfiguration

    var body: some View {
        LabControlSection(
            "Model and decoding",
            detail: "Production is deterministic greedy decoding. Sampling controls only become behaviorally meaningful once temperature rises above zero."
        ) {
            LabControlGrid {
                LabControlRow("Sampler preset") {
                    LabEnumPicker(label: "Sampler", selection: preset)
                }
                LabControlRow("Request protocol", help: "Streaming matches production and measures first-token latency. Final response maximizes bulk throughput.") {
                    LabEnumPicker(label: "Protocol", selection: $arm.generation.requestMode)
                }
                LabControlRow("Temperature") {
                    LabValueSlider(value: $arm.generation.temperature, range: 0...2, step: 0.05)
                }
                LabControlRow("Prediction budget") {
                    Stepper("\(arm.generation.predictionTokens) tokens", value: $arm.generation.predictionTokens, in: 1...128)
                }
                LabControlRow("Top-k") {
                    Stepper("\(arm.generation.topK)", value: $arm.generation.topK, in: 0...1_000)
                }
                LabControlRow("Top-p") {
                    LabValueSlider(value: $arm.generation.topP, range: 0...1, step: 0.01)
                }
                LabControlRow("Min-p") {
                    LabValueSlider(value: $arm.generation.minP, range: 0...1, step: 0.01)
                }
                LabControlRow("Typical-p") {
                    LabValueSlider(value: $arm.generation.typicalP, range: 0...1, step: 0.01)
                }
                LabControlRow("Repeat penalty") {
                    LabValueSlider(value: $arm.generation.repeatPenalty, range: 0...3, step: 0.05)
                }
                LabControlRow("Repeat window") {
                    Stepper("\(arm.generation.repeatLastTokens) tokens", value: $arm.generation.repeatLastTokens, in: 0...8_192)
                }
                LabControlRow("Presence penalty") {
                    LabValueSlider(value: $arm.generation.presencePenalty, range: -2...2, step: 0.05)
                }
                LabControlRow("Frequency penalty") {
                    LabValueSlider(value: $arm.generation.frequencyPenalty, range: -2...2, step: 0.05)
                }
                LabControlRow("Generation seed") {
                    Stepper("\(arm.generation.seed)", value: $arm.generation.seed, in: -1...Int(Int32.max))
                }
                LabControlRow("Stop rule") {
                    HStack {
                        LabEnumPicker(label: "Stop", selection: $arm.generation.stopRule)
                        if arm.generation.stopRule == .characterLimit {
                            Stepper(
                                "\(arm.generation.stopCharacterLimit) chars",
                                value: $arm.generation.stopCharacterLimit,
                                in: 1...4_096
                            )
                        }
                    }
                }
                LabControlRow("Confidence evidence", help: "Requests token probabilities. A nonzero threshold suppresses candidates only when the helper returns probability evidence.") {
                    HStack {
                        Stepper("Top \(arm.generation.probabilityCount)", value: $arm.generation.probabilityCount, in: 0...20)
                        LabValueSlider(
                            value: $arm.generation.minimumMeanTokenProbability,
                            range: 0...1,
                            step: 0.01
                        )
                    }
                }
                LabControlRow("Prompt cache") {
                    Toggle("Reuse matching prompt state", isOn: $arm.generation.cachePrompt)
                        .toggleStyle(.checkbox)
                }
            }

            DisclosureGroup("Advanced sampler laboratory") {
                LabControlGrid {
                    LabControlRow("Sampler order") {
                        TextField("sampler order", text: $arm.generation.advanced.samplerOrder)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabControlRow("Top-n sigma") {
                        LabValueSlider(value: $arm.generation.advanced.topNSigma, range: -1...10, step: 0.1)
                    }
                    LabControlRow("XTC probability") {
                        LabValueSlider(value: $arm.generation.advanced.xtcProbability, range: 0...1, step: 0.01)
                    }
                    LabControlRow("XTC threshold") {
                        LabValueSlider(value: $arm.generation.advanced.xtcThreshold, range: 0...1, step: 0.01)
                    }
                    LabControlRow("DRY multiplier") {
                        LabValueSlider(value: $arm.generation.advanced.dryMultiplier, range: 0...5, step: 0.05)
                    }
                    LabControlRow("DRY base") {
                        LabValueSlider(value: $arm.generation.advanced.dryBase, range: 1...4, step: 0.05)
                    }
                    LabControlRow("DRY allowed length") {
                        Stepper("\(arm.generation.advanced.dryAllowedLength)", value: $arm.generation.advanced.dryAllowedLength, in: 0...64)
                    }
                    LabControlRow("DRY history", help: "-1 keeps llama-server's default; 0 disables the history window.") {
                        Stepper(
                            arm.generation.advanced.dryPenaltyLastN < 0
                                ? "Server default"
                                : "\(arm.generation.advanced.dryPenaltyLastN) tokens",
                            value: $arm.generation.advanced.dryPenaltyLastN,
                            in: -1...8_192
                        )
                    }
                    LabControlRow("Dynamic temperature") {
                        HStack {
                            LabValueSlider(value: $arm.generation.advanced.dynamicTemperatureRange, range: 0...2, step: 0.05)
                            Text("exp")
                            LabValueSlider(value: $arm.generation.advanced.dynamicTemperatureExponent, range: 0...4, step: 0.05)
                        }
                    }
                    LabControlRow("Mirostat") {
                        HStack {
                            Stepper("mode \(arm.generation.advanced.mirostatMode)", value: $arm.generation.advanced.mirostatMode, in: 0...2)
                            LabValueSlider(value: $arm.generation.advanced.mirostatTau, range: 0...10, step: 0.1)
                            LabValueSlider(value: $arm.generation.advanced.mirostatEta, range: 0...1, step: 0.01)
                        }
                    }
                    LabControlRow("Grammar") {
                        LabEnumPicker(label: "Grammar", selection: $arm.generation.advanced.grammarMode)
                    }
                    LabControlRow("Logit bias JSON", help: "Optional llama.cpp logit_bias JSON. Invalid JSON is ignored, never interpolated into a prompt.") {
                        TextField("[]", text: $arm.generation.advanced.logitBiasRules)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabControlRow("End token") {
                        Toggle("Ignore EOS", isOn: $arm.generation.advanced.ignoreEndOfSequence)
                            .toggleStyle(.checkbox)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var preset: Binding<LabSamplerPreset> {
        Binding(
            get: { arm.generation.preset },
            set: { arm.generation.apply($0) }
        )
    }
}

private struct LabPromptEditor: View {
    @Binding var arm: LabArmConfiguration

    var body: some View {
        LabControlSection(
            "Prompt and context recipe",
            detail: "These controls determine the writing register, examples, scene representation, context allocation, and semantic intent hint."
        ) {
            LabControlGrid {
                LabControlRow("Prompt recipe") {
                    LabEnumPicker(label: "Recipe", selection: $arm.prompt.recipe)
                }
                LabControlRow("Register") {
                    LabEnumPicker(label: "Register", selection: $arm.prompt.registerOverride)
                }
                LabControlRow("Conversation selection") {
                    LabEnumPicker(label: "Selection", selection: $arm.prompt.conversationSelection)
                }
                LabControlRow("Conversation format") {
                    LabEnumPicker(label: "Format", selection: $arm.prompt.conversationFormat)
                }
                LabControlRow("Scene placement") {
                    LabEnumPicker(label: "Placement", selection: $arm.prompt.scenePlacement)
                }
                LabControlRow("Total prompt budget") {
                    Stepper("\(arm.prompt.maximumContextCharacters.formatted()) characters", value: $arm.prompt.maximumContextCharacters, in: 80...24_000, step: 100)
                }
                LabControlRow("Scene budget") {
                    Stepper("\(arm.prompt.maximumSceneCharacters.formatted()) characters", value: $arm.prompt.maximumSceneCharacters, in: 0...24_000, step: 100)
                }
                LabControlRow("Latest reply reserve") {
                    Stepper("\(arm.prompt.replyReserveCharacters.formatted()) characters", value: $arm.prompt.replyReserveCharacters, in: 0...12_000, step: 100)
                }
                LabControlRow("Cache-stable quantum") {
                    Stepper("\(arm.prompt.sceneBudgetQuantum) characters", value: $arm.prompt.sceneBudgetQuantum, in: 1...4_096)
                }
                LabControlRow("Conversation cap") {
                    HStack {
                        Stepper("\(arm.prompt.conversationTurnLimit) turns", value: $arm.prompt.conversationTurnLimit, in: 1...100)
                        Stepper("\(arm.prompt.conversationCharacterBudget.formatted()) chars", value: $arm.prompt.conversationCharacterBudget, in: 1...24_000, step: 100)
                    }
                }
                LabControlRow("Reference cap") {
                    Stepper("\(arm.prompt.referenceCharacterBudget.formatted()) chars", value: $arm.prompt.referenceCharacterBudget, in: 1...24_000, step: 100)
                }
                LabControlRow("Scene") {
                    Toggle("Include synthetic scene", isOn: $arm.prompt.includesScene)
                        .toggleStyle(.checkbox)
                }
                LabControlRow("Intent Futures") {
                    HStack {
                        Toggle("Include hint", isOn: $arm.prompt.includesIntentFutures)
                            .toggleStyle(.checkbox)
                        Stepper("\(arm.prompt.maximumIntentFutures) futures", value: $arm.prompt.maximumIntentFutures, in: 0...12)
                        LabValueSlider(value: $arm.prompt.intentPriorWeight, range: 0...1, step: 0.05)
                    }
                }
            }
        }
    }
}

private struct LabSummaryTile: View {
    let title: String
    let value: String
    let detail: String

    init(_ title: String, _ value: String, _ detail: String) {
        self.title = title
        self.value = value
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 9))
    }
}
