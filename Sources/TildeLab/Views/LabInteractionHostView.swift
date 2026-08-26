import AppKit
import CryptoKit
import SwiftUI

struct LabInteractionHostView: View {
    @State private var text = ""
    @State private var events: [LabInteractionHostEvent] = []
    @State private var baselineDigest: String?
    @State private var verificationMessage: String?
    @State private var probeRequest = 0
    @State private var probeResult: LabInteractionProbeResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            HSplitView {
                editorPane
                eventPane
            }
            .frame(minHeight: 430)
            footer
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 650)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Interaction Scene Host")
                .font(.title.weight(.bold))
            Text("A real AppKit text system for observing marked text, selection, acceptance, dismissal, and committed-text integrity. Event records contain only fixed labels, ranges, and counts—never what you type.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Native NSTextView").font(.headline)
                Spacer()
                Menu("Synthetic seed") {
                    Button("Reply confirmation") { text = "Yes, " }
                    Button("Email follow-up") { text = "Thanks for sending this over — I'll " }
                    Button("Prose continuation") { text = "The results suggest that " }
                }
                Button("Clear") {
                    text = ""
                    events.removeAll()
                    baselineDigest = nil
                    verificationMessage = nil
                    probeResult = nil
                }
            }
            LabInstrumentedTextView(
                text: $text,
                probeRequest: probeRequest,
                onEvent: record,
                onProbe: { probeResult = $0 }
            )
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
            HStack {
                Label("\(text.count) committed characters", systemImage: "textformat.abc")
                    .font(.callout.monospacedDigit())
                Spacer()
                Button("Set integrity baseline") {
                    baselineDigest = digest(text)
                    verificationMessage = "Baseline captured in memory"
                }
                Button("Verify committed text") {
                    guard let baselineDigest else {
                        verificationMessage = "Set a baseline first"
                        return
                    }
                    verificationMessage = digest(text) == baselineDigest
                        ? "Committed text matches baseline"
                        : "Committed text changed"
                }
            }
            if let verificationMessage {
                Label(
                    verificationMessage,
                    systemImage: verificationMessage.contains("matches") ? "checkmark.seal.fill" : "info.circle"
                )
                .font(.callout)
                .foregroundStyle(verificationMessage.contains("matches") ? .green : .secondary)
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Automated native host probe")
                        .font(.headline)
                    Text("Exercises marked-text set, dismissal, commit, Tab, selection, and committed-text integrity in this real NSTextView.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Run Probe", systemImage: "play.fill") { probeRequest += 1 }
                    .buttonStyle(.borderedProminent)
            }
            if let probeResult {
                Label(
                    probeResult.passed
                        ? "Passed all \(probeResult.checkCount) native text-system checks"
                        : "Failed: \(probeResult.failures.joined(separator: " · "))",
                    systemImage: probeResult.passed ? "checkmark.seal.fill" : "xmark.octagon.fill"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(probeResult.passed ? .green : .red)
            }
        }
        .padding(12)
        .frame(minWidth: 500)
    }

    private var eventPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Text-system events").font(.headline)
                Spacer()
                Button("Clear events") { events.removeAll() }
                    .disabled(events.isEmpty)
            }
            if events.isEmpty {
                ContentUnavailableView(
                    "Waiting for input",
                    systemImage: "keyboard",
                    description: Text("Type with Tilde selected, then accept, dismiss, edit, or move the selection.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(events.reversed()) { event in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(event.kind.rawValue)
                                .font(.callout.monospaced().weight(.semibold))
                            Spacer()
                            Text(event.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text("selection \(range(event.selection)) · marked \(range(event.marked)) · \(event.characterCount) chars")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.inset)
            }
        }
        .padding(12)
        .frame(minWidth: 320)
    }

    private var footer: some View {
        Label(
            "This host observes the real macOS text system. Automated focus stealing and input-source switching are intentionally owner-triggered; background Reply runs never open this window.",
            systemImage: "hand.raised.fill"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func record(_ event: LabInteractionHostEvent) {
        events.append(event)
        if events.count > 500 { events.removeFirst(events.count - 500) }
    }

    private func range(_ value: NSRange) -> String {
        value.location == NSNotFound ? "none" : "\(value.location):\(value.length)"
    }

    private func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private struct LabInstrumentedTextView: NSViewRepresentable {
    @Binding var text: String
    let probeRequest: Int
    let onEvent: (LabInteractionHostEvent) -> Void
    let onProbe: (LabInteractionProbeResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEvent: onEvent, onProbe: onProbe)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = InstrumentedTextView()
        textView.delegate = context.coordinator
        textView.eventHandler = context.coordinator.record
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = .systemFont(ofSize: 18)
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        scrollView.documentView = textView

        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? InstrumentedTextView else { return }
        context.coordinator.onEvent = onEvent
        context.coordinator.onProbe = onProbe
        textView.eventHandler = context.coordinator.record
        if textView.string != text {
            textView.string = text
            context.coordinator.record(kind: .programmaticSeed, textView: textView)
        }
        if context.coordinator.lastProbeRequest != probeRequest {
            context.coordinator.lastProbeRequest = probeRequest
            context.coordinator.runProbe(in: textView)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onEvent: (LabInteractionHostEvent) -> Void
        var onProbe: (LabInteractionProbeResult) -> Void
        var lastProbeRequest = 0

        init(
            text: Binding<String>,
            onEvent: @escaping (LabInteractionHostEvent) -> Void,
            onProbe: @escaping (LabInteractionProbeResult) -> Void
        ) {
            _text = text
            self.onEvent = onEvent
            self.onProbe = onProbe
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? InstrumentedTextView else { return }
            text = textView.string
            record(kind: .textChanged, textView: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? InstrumentedTextView else { return }
            record(kind: .selectionChanged, textView: textView)
        }

        func record(kind: LabInteractionHostEvent.Kind, textView: InstrumentedTextView) {
            onEvent(LabInteractionHostEvent(
                kind: kind,
                selection: textView.selectedRange(),
                marked: textView.markedRange(),
                characterCount: textView.string.count
            ))
        }

        func runProbe(in textView: InstrumentedTextView) {
            let seed = "Synthetic committed prefix "
            textView.string = seed
            textView.setSelectedRange(NSRange(location: (seed as NSString).length, length: 0))
            record(kind: .programmaticSeed, textView: textView)

            var failures: [String] = []
            textView.setMarkedText(
                "candidate",
                selectedRange: NSRange(location: 9, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0)
            )
            if textView.markedRange().location == NSNotFound { failures.append("marked text") }

            textView.doCommand(by: #selector(NSTextView.cancelOperation(_:)))
            textView.unmarkText()
            if textView.markedRange().location != NSNotFound { failures.append("Escape dismissal") }

            textView.setSelectedRange(NSRange(location: (seed as NSString).length, length: 0))
            textView.setMarkedText(
                "candidate",
                selectedRange: NSRange(location: 9, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0)
            )
            let marked = textView.markedRange()
            textView.insertText("candidate", replacementRange: marked)
            if textView.markedRange().location != NSNotFound { failures.append("commit clears mark") }
            if textView.string != seed + "candidate" { failures.append("committed integrity") }

            let committed = textView.string
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            if textView.selectedRange().location != 0 { failures.append("selection movement") }
            textView.setSelectedRange(NSRange(location: (committed as NSString).length, length: 0))

            let beforeTab = textView.string
            textView.doCommand(by: #selector(NSTextView.insertTab(_:)))
            if textView.string == beforeTab { failures.append("Tab command") }

            textView.string = committed
            text = committed
            record(kind: .textChanged, textView: textView)
            onProbe(LabInteractionProbeResult(failures: failures))
        }
    }
}

private final class InstrumentedTextView: NSTextView {
    var eventHandler: ((LabInteractionHostEvent.Kind, InstrumentedTextView) -> Void)?

    override func setMarkedText(
        _ string: Any,
        selectedRange: NSRange,
        replacementRange: NSRange
    ) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        eventHandler?(.markedTextSet, self)
    }

    override func unmarkText() {
        super.unmarkText()
        eventHandler?(.markedTextCleared, self)
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        super.insertText(insertString, replacementRange: replacementRange)
        eventHandler?(.textCommitted, self)
    }

    override func doCommand(by selector: Selector) {
        if selector == #selector(insertTab(_:)) { eventHandler?(.tab, self) }
        if selector == #selector(cancelOperation(_:)) { eventHandler?(.escape, self) }
        super.doCommand(by: selector)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { eventHandler?(.focusGained, self) }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result { eventHandler?(.focusLost, self) }
        return result
    }
}

private struct LabInteractionHostEvent: Identifiable {
    enum Kind: String {
        case focusGained = "focus-gained"
        case focusLost = "focus-lost"
        case markedTextSet = "marked-text-set"
        case markedTextCleared = "marked-text-cleared"
        case textCommitted = "text-committed"
        case textChanged = "text-changed"
        case selectionChanged = "selection-changed"
        case programmaticSeed = "programmatic-seed"
        case tab
        case escape
    }

    let id = UUID()
    let timestamp = Date()
    let kind: Kind
    let selection: NSRange
    let marked: NSRange
    let characterCount: Int
}

private struct LabInteractionProbeResult {
    let failures: [String]
    let checkCount = 6
    var passed: Bool { failures.isEmpty }
}
