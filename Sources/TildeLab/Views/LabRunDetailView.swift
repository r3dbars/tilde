import SwiftUI
import TildeLabKit

struct LabRunDetailView: View {
    let report: LabRunReport
    let baseline: LabRunReport?
    let isPinnedBaseline: Bool
    let scenario: (LabCaseResult) -> LabScenario?
    let onPinBaseline: () -> Void
    let onDelete: () -> Void

    @State private var confirmingDelete = false
    @State private var inspectedCase: LabCaseResult?

    private var comparison: LabRunComparison? {
        baseline.map { LabRunComparison(current: report, baseline: $0) }
    }

    private var isModelQualityRun: Bool {
        report.arm.scoring.usesModelOutputQuality
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summary
                provenanceCard
                qualityMetrics
                breakdownCard
                promotionCard
                if let comparison { comparisonCard(comparison) }
                outcomeCard
                decisionReasonCard
                failureTaxonomyCard
                categoryCard
                failureCard
                manifestCard
            }
            .padding(24)
            .frame(maxWidth: 1_080, alignment: .leading)
        }
        .navigationTitle(report.arm.id)
        .toolbar {
            ToolbarItemGroup {
                Button(
                    isPinnedBaseline ? "Unpin Baseline" : "Pin Baseline",
                    systemImage: isPinnedBaseline ? "pin.slash" : "pin"
                ) { onPinBaseline() }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .sheet(item: $inspectedCase) { result in
            LabCaseInspector(result: result, scenario: scenario(result))
        }
        .confirmationDialog(
            "Delete this aggregate report?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Report", role: .destructive, action: onDelete)
        }
    }

    private var breakdownCard: some View {
        GroupBox("Where the savings came from") {
            HStack(alignment: .top, spacing: 28) {
                BreakdownColumn("Context", rows: breakdown { $0.contextVariant.rawValue })
                BreakdownColumn("Checkpoint", rows: breakdown { $0.replayCheckpoint.rawValue })
                BreakdownColumn("Source", rows: breakdown { $0.scenarioSource.rawValue })
                BreakdownColumn("Corpus", rows: breakdown { $0.corpusID ?? "unregistered" })
            }
            .padding(8)
        }
    }

    private func breakdown(_ key: (LabCaseResult) -> String) -> [(String, Double, Int)] {
        Dictionary(grouping: report.cases, by: key)
            .map { label, cases in
                let baseline = cases.reduce(0) { $0 + $1.baselineKeystrokes }
                let net = cases.reduce(0) { $0 + $1.netKeystrokesSaved }
                return (label, baseline > 0 ? Double(net) / Double(baseline) : 0, cases.count)
            }
            .sorted { $0.0 < $1.0 }
    }

    private var summary: some View {
        HStack(alignment: .center, spacing: 24) {
            ZStack {
                Circle()
                    .fill(verdictColor.opacity(0.12))
                VStack(spacing: 3) {
                    Image(systemName: verdictIcon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(verdictColor)
                    Text(isModelQualityRun ? "QUALITY TEST" : report.verdict.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .minimumScaleFactor(0.6)
                }
                .padding(12)
            }
            .frame(width: 132, height: 132)

            VStack(alignment: .leading, spacing: 7) {
                Text(isModelQualityRun
                     ? "\(report.metrics.qualityScore.map(String.init) ?? "—")/100"
                     : percent(report.metrics.netKeystrokeSavingsRate))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(isModelQualityRun ? "OUTPUT QUALITY" : "NET KEYSTROKE SAVINGS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(report.suiteName)
                    .font(.title2.weight(.semibold))
                Text("\(distinctRootCount.formatted()) distinct situations · \(report.metrics.totalCases.formatted()) evaluations · \(report.execution.concurrency) concurrent requests")
                    .foregroundStyle(.secondary)
                Text(report.finishedAt.formatted(date: .complete, time: .standard))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(report.plainEnglishOutcome)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(report.verdict == .eligible ? .green : .secondary)
                Text(isModelQualityRun
                     ? "Human acceptable × factual × within the 3-word cap. Latency is not part of this score."
                     : "\(report.metrics.netKeystrokesSavedPer1000Characters.formatted(.number.precision(.fractionLength(1)))) saved / 1,000 characters · diagnostic score \(report.metrics.qualityScore.map(String.init) ?? "—")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var distinctRootCount: Int {
        Set(report.cases.map { $0.rootScenarioID ?? $0.scenarioID }).count
    }

    private var provenanceCard: some View {
        let eligibility = report.effectiveEvidenceEligibility
        return GroupBox("Research evidence") {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    eligibility.eligible
                        ? "Decision-grade evidence"
                        : "Readable, but not decision-grade evidence",
                    systemImage: eligibility.eligible
                        ? "checkmark.shield.fill"
                        : "exclamationmark.shield.fill"
                )
                .font(.headline)
                .foregroundStyle(eligibility.eligible ? .green : .orange)

                if !eligibility.reasons.isEmpty {
                    Text(eligibility.reasons.map(\.rawValue).joined(separator: " · "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    ManifestRow("Report", report.schema)
                    ManifestRow("Review", report.review?.status.title ?? "Unavailable")
                    if let provenance = report.provenance {
                        ManifestRow(
                            "Hypothesis",
                            provenance.experiment.map { "\($0.id) — \($0.hypothesis)" }
                                ?? "Unregistered"
                        )
                        ManifestRow(
                            "Source",
                            provenance.source.gitCommitSHA.map {
                                "\($0.prefix(12)) · \(provenance.source.treeState.rawValue)"
                            } ?? "Unavailable"
                        )
                        ManifestRow(
                            "Runner",
                            provenance.source.runnerSHA256.map { String($0.prefix(16)) }
                                ?? "Unavailable"
                        )
                        ManifestRow(
                            "Environment",
                            [
                                provenance.environment.operatingSystemVersion,
                                provenance.environment.operatingSystemBuild,
                                provenance.environment.hardwareClass,
                            ].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
                                ?? "Unavailable"
                        )
                        ManifestRow(
                            "Power / thermal",
                            "\(provenance.environment.machine.isOnACPower ? "AC" : "battery or unknown") · \(provenance.environment.machine.lowPowerModeEnabled ? "Low Power Mode" : "normal power") · \(provenance.environment.machine.thermalLevel.rawValue)"
                        )
                        ManifestRow(
                            "Invocation",
                            provenance.invocation.digestSHA256.map { String($0.prefix(16)) }
                                ?? "Unavailable"
                        )
                    } else {
                        ManifestRow("Provenance", "Unavailable (legacy report)")
                    }
                }
                .font(.callout)
                .textSelection(.enabled)
            }
            .padding(8)
        }
    }

    private var qualityMetrics: some View {
        GroupBox(isModelQualityRun ? "Output quality" : "Keystroke savings, quality, and speed") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                if isModelQualityRun {
                    RunMetricCard("Quality score", "\(report.metrics.qualityScore.map(String.init) ?? "—")/100", "quality-only headline")
                }
                RunMetricCard("Human acceptable", percent(report.metrics.usefulnessRate), "reviewed answer path")
                RunMetricCard("Exact path", percent(report.metrics.exactPredictionRate), "recorded continuation")
                RunMetricCard("Accepted alternative", percent(report.metrics.acceptableAlternativeRate), "different valid wording")
                RunMetricCard("Factual", percent(report.metrics.factualityRate), "grounded candidates")
                RunMetricCard("Brevity", percent(report.metrics.brevityRate), "within case limit")
                RunMetricCard("Exact@1", percent(report.metrics.exactMatchAt1Rate), "first word")
                RunMetricCard("Exact@3", percent(report.metrics.exactMatchAt3Rate), "first three words")
                RunMetricCard("Bad shows", percent(report.metrics.badSuggestionRate), "wrong or unwanted")
                if !isModelQualityRun {
                    RunMetricCard("Ordinary quiet", optionalPercent(report.metrics.ordinaryRestraintRate), "avoid interruptions")
                    RunMetricCard("Sensitive quiet", optionalPercent(report.metrics.sensitiveRestraintRate), "must remain perfect")
                    RunMetricCard("Pair pass", optionalPercent(report.metrics.counterfactualPairPassRate), "both facts correct")
                    RunMetricCard("Gross saved", report.metrics.grossKeystrokesSaved.formatted(), "accepted characters")
                    RunMetricCard("Net saved", report.metrics.netKeystrokesSaved.formatted(), "after all overhead")
                    RunMetricCard("Accept cost", report.metrics.acceptanceKeystrokes.formatted(), "Tab / word accepts")
                    RunMetricCard("Dismiss + correct", (report.metrics.dismissalKeystrokes + report.metrics.correctionKeystrokes).formatted(), "interruption overhead")
                    RunMetricCard("Throughput", report.metrics.throughputModelRequestsPerSecond.formatted(.number.precision(.fractionLength(1))), "model requests / second")
                    RunMetricCard("First token P50", milliseconds(report.metrics.firstTokenLatency.p50Milliseconds), "streamed response")
                    RunMetricCard("P50", milliseconds(report.metrics.latency.p50Milliseconds), "model response")
                    RunMetricCard("P95", milliseconds(report.metrics.latency.p95Milliseconds), "model response")
                    RunMetricCard(
                        "Mean confidence",
                        report.metrics.meanTokenProbability.map(percent) ?? "Not requested",
                        "token probability"
                    )
                }
            }
            .padding(8)
            if isModelQualityRun {
                Text("Diagnostic only · P95 \(milliseconds(report.metrics.latency.p95Milliseconds)) · \(report.metrics.throughputModelRequestsPerSecond.formatted(.number.precision(.fractionLength(1)))) requests/s")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }
        }
    }

    @ViewBuilder
    private var promotionCard: some View {
        if let eligible = report.metrics.promotionEligible {
            GroupBox("Promotion gates") {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        eligible ? "This result is eligible for holdout confirmation." : "This result is not ready for holdout confirmation.",
                        systemImage: eligible ? "checkmark.seal.fill" : "xmark.shield.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(eligible ? .green : .orange)
                    if !report.metrics.promotionGateFailures.isEmpty {
                        Text(report.metrics.promotionGateFailures.map(gateLabel).joined(separator: " · "))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 14) {
                        GateBadge("Bad suggestions", report.metrics.gates.badSuggestions)
                        GateBadge("Sensitive", report.metrics.gates.sensitiveSituations)
                        GateBadge("Temporal", report.metrics.gates.temporalIntegrity)
                        GateBadge("Latency", report.metrics.gates.latency)
                        GateBadge("Privacy", report.metrics.gates.privacy)
                        GateBadge("Interaction", report.metrics.gates.interactionIntegrity)
                    }
                    Text(report.metrics.gates.releaseEligible
                         ? "Release eligible"
                         : report.metrics.gates.researchEligible
                            ? "Research eligible. Interaction Bench must pass before release."
                            : "Not research eligible.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
        }
    }

    private func comparisonCard(_ value: LabRunComparison) -> some View {
        GroupBox("Versus previous compatible run") {
            HStack(spacing: 28) {
                if isModelQualityRun {
                    DeltaMetric(
                        "Quality score",
                        value.scoreDelta.map { signed($0) + " points" } ?? "—",
                        favorable: (value.scoreDelta ?? 0) >= 0
                    )
                } else {
                    DeltaMetric("Net savings", signedPercent(value.netKeystrokeSavingsRateDelta), favorable: value.netKeystrokeSavingsRateDelta >= 0)
                }
                DeltaMetric("Human acceptable", signedPercent(value.usefulnessRateDelta), favorable: value.usefulnessRateDelta >= 0)
                DeltaMetric("Exact@1", signedPercent(value.exactMatchAt1Delta), favorable: value.exactMatchAt1Delta >= 0)
                DeltaMetric(
                    "P95",
                    value.p95LatencyDeltaMilliseconds.map { signed($0) + " ms" } ?? "—",
                    favorable: (value.p95LatencyDeltaMilliseconds ?? 0) <= 0
                )
                DeltaMetric(
                    "Throughput",
                    signed(value.throughputDelta) + "/s",
                    favorable: value.throughputDelta >= 0
                )
            }
            .padding(8)
        }
    }

    private var failureTaxonomyCard: some View {
        GroupBox("Failure taxonomy") {
            if report.metrics.failureCategoryCounts.isEmpty {
                Text("No classified failures in this run.")
                    .foregroundStyle(.secondary)
                    .padding(8)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    ForEach(LabFailureCategory.allCases.filter { $0 != .none }, id: \.rawValue) { category in
                        HStack {
                            Text(category.rawValue).font(.callout.monospaced())
                            Spacer()
                            Text(report.metrics.failureCategoryCounts[category.rawValue, default: 0].formatted())
                                .font(.callout.monospacedDigit().weight(.semibold))
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private var outcomeCard: some View {
        GroupBox("Outcome counts") {
            HStack(spacing: 28) {
                CountMetric("Human acceptable", report.metrics.useful, .green)
                CountMetric("Wrong", report.metrics.wrong, .red)
                CountMetric("Silent", report.metrics.silent, .orange)
                CountMetric("Correct silence", report.metrics.correctSilence, .blue)
                CountMetric("Unwanted", report.metrics.unwanted, .red)
                CountMetric("Suppressed", report.metrics.policySuppressions, .secondary)
            }
            .padding(8)
        }
    }

    private var decisionReasonCard: some View {
        GroupBox("Decision reasons") {
            if report.metrics.decisionReasonCounts.isEmpty {
                Text("This legacy run predates reason accounting.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(8)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), alignment: .leading, spacing: 10) {
                    ForEach(report.metrics.decisionReasonCounts.keys.sorted(), id: \.self) { reason in
                        HStack {
                            Text(reason)
                                .font(.callout.monospaced())
                                .lineLimit(1)
                            Spacer()
                            Text(report.metrics.decisionReasonCounts[reason, default: 0].formatted())
                                .font(.callout.monospacedDigit().weight(.semibold))
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private var categoryCard: some View {
        GroupBox("By scenario category") {
            VStack(spacing: 0) {
                ForEach(categoryRows, id: \.name) { row in
                    HStack {
                        Text(row.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(row.useful) acceptable")
                            .foregroundStyle(.green)
                            .frame(width: 90, alignment: .trailing)
                        Text("\(row.wrong) wrong")
                            .foregroundStyle(row.wrong > 0 ? .red : .secondary)
                            .frame(width: 90, alignment: .trailing)
                        Text("\(row.silent) silent")
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .trailing)
                    }
                    .font(.callout.monospacedDigit())
                    .padding(.vertical, 7)
                    if row.name != categoryRows.last?.name { Divider() }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    @ViewBuilder
    private var failureCard: some View {
        let failures = report.cases.filter {
            $0.outcome == .wrong || $0.outcome == .silent || $0.outcome == .unwanted
                || $0.outcome == .timeout || $0.outcome == .error
        }
        if !failures.isEmpty {
            GroupBox("Cases to investigate") {
                VStack(spacing: 0) {
                    ForEach(failures.prefix(100)) { result in
                        Button {
                            inspectedCase = result
                        } label: {
                            HStack {
                                Image(systemName: outcomeIcon(result.outcome))
                                    .foregroundStyle(outcomeColor(result.outcome))
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.scenarioID)
                                    Text(result.decisionReason.rawValue)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(result.outcome.rawValue)
                                    .foregroundStyle(.secondary)
                                if let latency = result.latencyMilliseconds {
                                    Text("\(latency) ms")
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .frame(width: 80, alignment: .trailing)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .font(.callout)
                        .padding(.vertical, 6)
                        Divider()
                    }
                    if failures.count > 100 {
                        Text("Showing the first 100 of \(failures.count.formatted()) cases.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private var manifestCard: some View {
        GroupBox("Reproducibility manifest") {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                ManifestRow("Suite digest", report.suiteDigestSHA256)
                ManifestRow("Inference", report.assets.inferenceBackend.title)
                ManifestRow("Model trust", report.assets.verificationMode.title)
                ManifestRow("Model", "\(report.assets.modelIdentifier) @ \(report.assets.modelRevision.prefix(12))")
                ManifestRow(
                    report.assets.inferenceBackend == .localLlama ? "Model SHA-256" : "Model identity SHA-256",
                    report.assets.modelSHA256
                )
                ManifestRow("Helper SHA-256", report.assets.helperSHA256)
                ManifestRow("Arm", report.arm.id)
                ManifestRow("Sampler", report.arm.generation.preset.title)
                ManifestRow("Temperature", report.arm.generation.temperature.formatted())
                ManifestRow("Prompt recipe", report.arm.prompt.recipe.title)
                ManifestRow("Register", report.arm.prompt.registerOverride.title)
                ManifestRow("Cleaner", report.arm.judgment.cleanerPreset.title)
                ManifestRow("Scoring", report.arm.scoring.policyVersion)
                ManifestRow("Workers / slots", "\(report.execution.workerCount) / \(report.execution.slotsPerWorker)")
                ManifestRow("Context", "\(report.execution.contextSizePerSlot) tokens per slot")
                ManifestRow("Batch / micro-batch", "\(report.execution.batchSize) / \(report.execution.microBatchSize)")
                ManifestRow("KV cache", "\(report.execution.keyCacheType.rawValue) / \(report.execution.valueCacheType.rawValue)")
                ManifestRow("Seed", String(report.execution.seed))
                ManifestRow(
                    "Privacy",
                    report.privacy.networkInference
                        ? "Certified synthetic prompts sent through Codex; no text or path persisted"
                        : "No fixture text, prompt, output, or path persisted"
                )
            }
            .font(.callout)
            .textSelection(.enabled)
            .padding(8)
        }
    }

    private var categoryRows: [(name: String, useful: Int, wrong: Int, silent: Int)] {
        Dictionary(grouping: report.cases, by: \.category)
            .map { name, cases in
                (
                    name,
                    cases.filter { $0.outcome == .useful }.count,
                    cases.filter { $0.outcome == .wrong || $0.outcome == .unwanted }.count,
                    cases.filter { $0.outcome == .silent || $0.outcome == .correctSilence }.count
                )
            }
            .sorted { $0.name < $1.name }
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }

    private func optionalPercent(_ value: Double?) -> String {
        value.map(percent) ?? "—"
    }

    private func gateLabel(_ code: String) -> String {
        switch code {
        case "incomplete-run": "Timeout or protocol error"
        case "missing-usefulness-cases": "No reply cases"
        case "usefulness-below-80": "Human-acceptable replies below 80%"
        case "missing-ordinary-silence-cases": "No ordinary-silence cases"
        case "ordinary-restraint-below-98": "Ordinary quiet below 98%"
        case "missing-sensitive-silence-cases": "No sensitive cases"
        case "sensitive-restraint-not-perfect": "Sensitive quiet below 100%"
        case "factuality-below-99": "Factuality below 99%"
        case "missing-counterfactual-pairs": "No counterfactual pairs"
        case "counterfactual-pairs-below-80": "Pair pass below 80%"
        case "missing-latency-samples": "No latency samples"
        case "p95-latency-over-1000ms": "P95 above 1,000 ms"
        case "bad-suggestion-gate": "Bad-suggestion gate failed"
        case "sensitive-situation-gate": "Sensitive-situation gate failed or not run"
        case "temporal-integrity-gate": "Temporal-integrity gate failed"
        case "latency-gate": "Latency gate failed or not run"
        case "privacy-gate": "Privacy gate failed"
        default: code
        }
    }

    private func signedPercent(_ value: Double) -> String {
        signed(value * 100) + " pp"
    }

    private func signed<T: BinaryInteger>(_ value: T) -> String {
        value >= 0 ? "+\(value)" : String(value)
    }

    private func signed(_ value: Double) -> String {
        let formatted = abs(value).formatted(.number.precision(.fractionLength(1)))
        return value >= 0 ? "+\(formatted)" : "−\(formatted)"
    }

    private func milliseconds(_ value: Int?) -> String {
        value.map { "\($0) ms" } ?? "—"
    }

    private func outcomeIcon(_ outcome: LabCaseOutcome) -> String {
        switch outcome {
        case .useful, .correctSilence: "checkmark.circle.fill"
        case .wrong, .unwanted: "xmark.circle.fill"
        case .silent: "minus.circle.fill"
        case .timeout, .error: "exclamationmark.triangle.fill"
        }
    }

    private func outcomeColor(_ outcome: LabCaseOutcome) -> Color {
        switch outcome {
        case .useful, .correctSilence: .green
        case .wrong, .unwanted: .red
        case .silent: .orange
        case .timeout, .error: .red
        }
    }

    private var verdictIcon: String {
        switch report.verdict {
        case .eligible: "checkmark.seal.fill"
        case .candidate: "flag.checkered"
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private struct RunMetricCard: View {
    let title: String
    let value: String
    let detail: String

    init(_ title: String, _ value: String, _ detail: String) {
        self.title = title
        self.value = value
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct DeltaMetric: View {
    let title: String
    let value: String
    let favorable: Bool

    init(_ title: String, _ value: String, favorable: Bool) {
        self.title = title
        self.value = value
        self.favorable = favorable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(favorable ? .green : .red)
        }
    }
}

private struct CountMetric: View {
    let title: String
    let value: Int
    let color: Color

    init(_ title: String, _ value: Int, _ color: Color) {
        self.title = title
        self.value = value
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.formatted())
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

private struct GateBadge: View {
    let label: String
    let status: LabGateStatus

    init(_ label: String, _ status: LabGateStatus) {
        self.label = label
        self.status = status
    }

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }

    private var icon: String {
        switch status {
        case .pass: "checkmark.circle.fill"
        case .fail: "xmark.circle.fill"
        case .notRun: "minus.circle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .pass: .green
        case .fail: .red
        case .notRun: .orange
        }
    }
}

private struct BreakdownColumn: View {
    let title: String
    let rows: [(String, Double, Int)]

    init(_ title: String, rows: [(String, Double, Int)]) {
        self.title = title
        self.rows = rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0).lineLimit(1)
                    Spacer()
                    Text(row.1.formatted(.percent.precision(.fractionLength(1))))
                        .monospacedDigit()
                    Text("n=\(row.2)").foregroundStyle(.tertiary).monospacedDigit()
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ManifestRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .trailing)
            Text(value)
                .fontDesign(.monospaced)
        }
    }
}

private struct LabCaseInspector: View {
    @Environment(\.dismiss) private var dismiss
    let result: LabCaseResult
    let scenario: LabScenario?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.scenarioID)
                        .font(.title2.weight(.semibold))
                    Text("\(result.outcome.rawValue) · \(result.decisionReason.rawValue)")
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            GroupBox("Recorded result") {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                    InspectorRow("Offered", result.offered ? "yes" : "no")
                    InspectorRow("Model requested", result.modelRequested ? "yes" : "no")
                    InspectorRow("Policy suppressed", result.policySuppressed ? "yes" : "no")
                    InspectorRow("Answer match", result.answerMatchKind.rawValue)
                    InspectorRow("Exact continuation path", result.exactContinuationMatched ? "matched" : "not matched")
                    InspectorRow("Exact @1 / @2 / @3", "\(yesNo(result.exactMatchAt1)) / \(yesNo(result.exactMatchAt2)) / \(yesNo(result.exactMatchAt3))")
                    InspectorRow("Accepted alternative", result.acceptablePrefixMatched || result.acceptableContinuationMatched ? "matched" : "not matched")
                    InspectorRow("Full-reply facts", result.requiredTermsSatisfied ? "all visible" : "not all visible yet")
                    InspectorRow("Forbidden fact", result.forbiddenTermViolation ? "violated" : "clear")
                    InspectorRow("Visible size", "\(result.visibleWordCount) words · \(result.visibleCharacterCount) characters")
                    InspectorRow("Replay", "\(result.replayCheckpoint.rawValue) · \(result.contextVariant.rawValue)")
                    InspectorRow("Source", result.scenarioSource.rawValue)
                    InspectorRow("Corpus", result.corpusID ?? "unregistered")
                    InspectorRow("Root situation", result.rootScenarioID ?? result.scenarioID)
                    InspectorRow("Temporal integrity", result.temporalIntegrityPassed ? "passed" : "development only")
                    InspectorRow("Net saved", "\(result.netKeystrokesSaved) (gross \(result.grossKeystrokesSaved), accept \(result.acceptanceKeystrokes), dismiss \(result.dismissalKeystrokes), correct \(result.correctionKeystrokes))")
                    InspectorRow("Failure bucket", result.failureCategory.rawValue)
                    InspectorRow("Latency", result.latencyMilliseconds.map { "\($0) ms" } ?? "not measured")
                    InspectorRow("First token", result.firstTokenMilliseconds.map { "\($0) ms" } ?? "not streamed")
                    InspectorRow("Confidence", result.meanTokenProbability.map { $0.formatted(.percent.precision(.fractionLength(1))) } ?? "not requested")
                }
                .padding(8)
            }

            if let scenario {
                GroupBox(inspectorEvidenceTitle(for: scenario)) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            FixtureText("Typed context", scenario.typedContext)
                            if let scene = scenario.scene {
                                ForEach(Array(scene.turns.enumerated()), id: \.offset) { index, turn in
                                    FixtureText("Turn \(index + 1) · \(turn.speaker.rawValue)", turn.text)
                                }
                                ForEach(Array(scene.references.enumerated()), id: \.offset) { index, value in
                                    FixtureText("Reference \(index + 1)", value)
                                }
                            }
                            if let value = scenario.evaluation.evidence.accessibilityText {
                                FixtureText("Accessibility extraction", value)
                            }
                            if let value = scenario.evaluation.evidence.OCRText {
                                FixtureText("OCR extraction", value)
                            }
                            if let value = scenario.evaluation.evidence.recordedScreenText {
                                FixtureText("Recorded screen text", value)
                            }
                            if let golden = scenario.expectation.goldenContinuation {
                                FixtureText("Golden continuation", golden)
                            }
                            if !scenario.expectation.acceptablePrefixes.isEmpty {
                                FixtureText("Acceptable prefixes", scenario.expectation.acceptablePrefixes.joined(separator: " · "))
                            }
                            if !scenario.expectation.acceptableContinuations.isEmpty {
                                FixtureText("Acceptable continuations", scenario.expectation.acceptableContinuations.joined(separator: " · "))
                            }
                            if !scenario.expectation.requiredTerms.isEmpty {
                                FixtureText("Required terms", scenario.expectation.requiredTerms.joined(separator: ", "))
                            }
                            if !scenario.expectation.forbiddenTerms.isEmpty {
                                FixtureText("Forbidden terms", scenario.expectation.forbiddenTerms.joined(separator: ", "))
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 320)
                }
            } else {
                ContentUnavailableView(
                    "Fixture text unavailable",
                    systemImage: "lock.doc",
                    description: Text("The report deliberately did not persist prompts or outputs. Reload the matching suite to inspect its synthetic fixture text.")
                )
            }

            Label(
                "Raw model output is never written into a run report.",
                systemImage: "lock.fill"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(minWidth: 680, minHeight: 620, alignment: .topLeading)
    }

    private func inspectorEvidenceTitle(for scenario: LabScenario) -> String {
        switch scenario.evaluation.source {
        case .historicalAccepted, .historicalTypedInstead:
            "Private historical case · memory-only inspection"
        case .publicCorpus:
            "Public corpus case · local memory-only inspection"
        case .synthetic, .handCurated:
            "Synthetic fixture · memory-only inspection"
        }
    }

    private func yesNo(_ value: Bool) -> String { value ? "yes" : "no" }
}

private struct InspectorRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).frame(width: 140, alignment: .trailing)
            Text(value).fontDesign(.monospaced)
        }
    }
}

private struct FixtureText: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
