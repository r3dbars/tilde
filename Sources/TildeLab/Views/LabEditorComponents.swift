import SwiftUI
import TildeLabKit

struct LabArmBar: View {
    @Bindable var store: LabWorkspaceStore

    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                TextField("Experiment name", text: $store.manifest.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 170, maxWidth: 260)
                Picker("Arm", selection: $store.selectedArmIndex) {
                    ForEach(Array(store.manifest.arms.indices), id: \.self) { index in
                        Text(store.manifest.arms[index].id).tag(index)
                    }
                }
                .frame(minWidth: 190, maxWidth: 280)
                Button("New", systemImage: "plus") { store.addArm(duplicatingCurrent: false) }
                Button("Duplicate", systemImage: "plus.square.on.square") {
                    store.addArm(duplicatingCurrent: true)
                }
                Button("Remove", systemImage: "minus") { store.removeSelectedArm() }
                    .disabled(store.manifest.arms.count <= 1)
                Spacer()
                Text("\(store.manifest.arms.count) arm\(store.manifest.arms.count == 1 ? "" : "s")")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Menu("Arm actions", systemImage: "ellipsis.circle") {
                    Button("Apply production-fidelity recipe") { store.applyProductionFidelity() }
                    Button("Reset all knobs to Lab defaults") { store.resetSelectedArmToLabDefaults() }
                    Divider()
                    Button("Export experiment manifest") { store.exportManifest() }
                }
            }
            .padding(6)
        }
    }
}

struct LabBenchHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}

struct LabControlSection<Content: View>: View {
    let title: String
    let detail: String?
    @ViewBuilder let content: Content

    init(_ title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 13) {
                if let detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .padding(8)
        }
    }
}

struct LabControlGrid<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 11) {
            content
        }
    }
}

struct LabControlRow<Content: View>: View {
    let label: String
    let help: String?
    @ViewBuilder let content: Content

    init(_ label: String, help: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.help = help
        self.content = content()
    }

    var body: some View {
        GridRow {
            HStack(spacing: 5) {
                Text(label)
                    .foregroundStyle(.secondary)
                if let help {
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .help(help)
                }
            }
            .frame(width: 190, alignment: .trailing)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LabEnumPicker<Option: LabNamedOption>: View where Option.AllCases: RandomAccessCollection {
    let label: String
    @Binding var selection: Option

    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(Array(Option.allCases), id: \.id) { option in
                Text(option.title).tag(option)
            }
        }
        .labelsHidden()
        .frame(minWidth: 170, maxWidth: 280)
    }
}

struct LabValueSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let fractionDigits: Int
    let suffix: String

    init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        fractionDigits: Int = 2,
        suffix: String = ""
    ) {
        _value = value
        self.range = range
        self.step = step
        self.fractionDigits = fractionDigits
        self.suffix = suffix
    }

    var body: some View {
        HStack {
            Slider(value: $value, in: range, step: step)
                .frame(maxWidth: 330)
            Text(value.formatted(.number.precision(.fractionLength(fractionDigits))) + suffix)
                .monospacedDigit()
                .frame(width: 74, alignment: .trailing)
        }
    }
}

struct LabToggleCloud<Option: LabNamedOption>: View where Option.AllCases: RandomAccessCollection {
    @Binding var selection: Set<Option>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(Option.allCases), id: \.id) { option in
                Toggle(option.title, isOn: binding(option))
                    .toggleStyle(.checkbox)
            }
        }
    }

    private func binding(_ option: Option) -> Binding<Bool> {
        Binding(
            get: { selection.contains(option) },
            set: { enabled in
                if enabled { selection.insert(option) } else { selection.remove(option) }
            }
        )
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: min(width, max(0, x - spacing)), height: y + rowHeight), points)
    }
}

struct LabHardGateBanner: View {
    var body: some View {
        Label(
            "Privacy, Secure Event Input, sensitive-scene silence, and committed-text integrity are hard gates. Experiment weights cannot disable or offset them.",
            systemImage: "lock.shield.fill"
        )
        .font(.callout.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.30), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct LabRunActionCard: View {
    @Bindable var store: LabWorkspaceStore

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if store.isRunning {
                    HStack {
                        ProgressView(value: store.progress.fractionCompleted)
                        Text(progressLabel)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Button("Cancel", role: .destructive) { store.cancelRun() }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ready for \(store.plannedEvaluations.formatted()) evaluations across \(store.manifest.arms.count) arm\(store.manifest.arms.count == 1 ? "" : "s")")
                                .font(.headline)
                            Text("One verified worker pool is shared across the matrix. Prompts and outputs remain memory-only.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Run Experiment Matrix", systemImage: "play.fill") { store.startRun() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(!store.canStart)
                    }
                }
            }
            .padding(8)
        }
    }

    private var progressLabel: String {
        let arm = store.progress.armID.map { " · \($0)" } ?? ""
        let matrix = store.progress.armCount > 1
            ? " · arm \(store.progress.armIndex + 1)/\(store.progress.armCount)"
            : ""
        return switch store.progress.phase {
        case .validating: "Validating matrix"
        case .verifyingAssets: "Verifying pinned model and helper"
        case .startingWorkers: "Loading model workers"
        case .running: "\(store.progress.completed.formatted()) / \(store.progress.total.formatted())\(matrix)\(arm)"
        case .finalizing: "Computing scorecards"
        case .stopping: "Stopping model workers"
        }
    }
}

struct LabSyntheticAuditCard: View {
    @Bindable var store: LabWorkspaceStore
    let bench: LabBenchKind

    private var report: LabBenchAuditReport? { store.benchAudits[bench] }
    private var isStale: Bool { report.map { $0.armID != store.selectedArm.id } ?? false }

    var body: some View {
        LabControlSection(
            "Synthetic policy audit",
            detail: "Runs fast deterministic fixtures against this bench's configured policy. It is not a substitute for a live model run or the foreground real-IME proof."
        ) {
            HStack(spacing: 18) {
                if let report {
                    Text(String(report.score))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(report.failed == 0 ? .green : .red)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(report.passed) passed · \(report.failed) failed · \(report.warnings) warnings")
                            .font(.headline.monospacedDigit())
                        Text(isStale ? "Result belongs to arm \(report.armID); run again for the selected arm." : "Arm \(report.armID) · \(report.generatedAt.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(isStale ? .orange : .secondary)
                    }
                } else {
                    Text("Not run")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Run Synthetic Audit", systemImage: "checkmark.circle") {
                    store.runSyntheticAudit(bench)
                }
                .buttonStyle(.borderedProminent)
            }

            if let report {
                DisclosureGroup("Inspect \(report.checks.count) checks") {
                    VStack(spacing: 0) {
                        ForEach(report.checks) { check in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: icon(check.status))
                                    .foregroundStyle(color(check.status))
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(check.title).font(.callout.weight(.semibold))
                                    Text(check.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 7)
                            Divider()
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private func icon(_ status: LabBenchCheckStatus) -> String {
        switch status {
        case .passed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        }
    }

    private func color(_ status: LabBenchCheckStatus) -> Color {
        switch status {
        case .passed: .green
        case .failed: .red
        case .warning: .orange
        }
    }
}
