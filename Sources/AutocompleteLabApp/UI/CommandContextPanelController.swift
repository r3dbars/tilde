import AppKit
import AutocompleteLabCore

struct CommandContextSnapshot: Equatable {
    let textBeforeCursorLength: Int
    let textAfterCursorLength: Int
    let selectedTextLength: Int
    let isSecure: Bool
    let fieldKind: AXFieldKind
    let canInsertWithAccessibility: Bool
    let hasCaretBounds: Bool
    let hasFieldBounds: Bool

    init(
        textBeforeCursorLength: Int,
        textAfterCursorLength: Int,
        selectedTextLength: Int,
        isSecure: Bool,
        fieldKind: AXFieldKind,
        canInsertWithAccessibility: Bool,
        hasCaretBounds: Bool,
        hasFieldBounds: Bool
    ) {
        self.textBeforeCursorLength = max(0, textBeforeCursorLength)
        self.textAfterCursorLength = max(0, textAfterCursorLength)
        self.selectedTextLength = max(0, selectedTextLength)
        self.isSecure = isSecure
        self.fieldKind = fieldKind
        self.canInsertWithAccessibility = canInsertWithAccessibility
        self.hasCaretBounds = hasCaretBounds
        self.hasFieldBounds = hasFieldBounds
    }

    init(context: FocusedTextContext) {
        self.init(
            textBeforeCursorLength: context.textBeforeCursor.count,
            textAfterCursorLength: context.textAfterCursor.count,
            selectedTextLength: context.selectedTextLength,
            isSecure: context.isSecure,
            fieldKind: context.fieldClassification.kind,
            canInsertWithAccessibility: context.capabilities.supportsAXInsertion,
            hasCaretBounds: context.caretRect != nil,
            hasFieldBounds: context.elementRect != nil
        )
    }

    var hasRequestText: Bool {
        selectedTextLength > 0 || textBeforeCursorLength > 0
    }

    var sourceName: String {
        selectedTextLength > 0 ? "selected text" : "current field"
    }

    var summaryText: String {
        if isSecure {
            return "Context: secure field, not read"
        }

        let source = selectedTextLength > 0
            ? "selected text, \(selectedTextLength) chars"
            : "current field, \(textBeforeCursorLength) chars before cursor"
        let after = textAfterCursorLength > 0 ? ", \(textAfterCursorLength) after" : ""
        let insert = canInsertWithAccessibility ? "AX insert yes" : "AX insert no"
        let bounds = hasCaretBounds ? "caret yes" : (hasFieldBounds ? "field bounds yes" : "bounds no")
        return "Context: \(source)\(after), \(fieldKind.rawValue), \(insert), \(bounds)"
    }
}

struct CommandContextPanelState: Equatable {
    let appDisplayName: String
    let bundleIdentifier: String?
    let supportStatus: CompatibilitySupportStatus
    let isAppEnabled: Bool
    let runtimeReport: RuntimeReadinessReport
    let context: CommandContextSnapshot?
    let suggestionText: String?
    let isLoading: Bool
    let statusMessage: String

    var appText: String {
        guard bundleIdentifier != nil else {
            return "App: none"
        }

        return "App: \(appDisplayName) | \(supportStatus.userFacingSummary)"
    }

    var pathText: String {
        switch supportStatus {
        case let .supported(profile):
            if profile.isSensitive {
                return "Path: off for sensitive app"
            }

            if !profile.canPresentSuggestions || !isAppEnabled {
                return "Path: copy fallback only; inline stays off"
            }

            return "Path: copy fallback; inline and mirror stay separate"
        case .denylisted:
            return "Path: off for blocked app"
        case .unsupported:
            return "Path: selected-text copy fallback only; inline stays off"
        }
    }

    var privacyText: String {
        if case .unsupported = supportStatus {
            return "Privacy: unsupported apps require selected text, use the local model, and copy only when you press Copy."
        }

        return "Privacy: runs only when you press Suggest, uses the local model, and copies only when you press Copy."
    }

    var normalTypingText: String {
        "Normal typing: untouched; this opens only from the menu or Settings."
    }

    var contextText: String {
        context?.summaryText ?? "Context: no readable focused text field"
    }

    var suggestionDisplayText: String {
        if isLoading {
            return "Thinking locally..."
        }

        guard let suggestionText,
              !suggestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "No suggestion yet."
        }

        return suggestionText
    }

    var requestButtonTitle: String {
        isLoading ? "Thinking..." : "Suggest"
    }

    var canRequestSuggestion: Bool {
        requestUnavailableReason == nil
    }

    var canCopySuggestion: Bool {
        guard !isLoading,
              let suggestionText else {
            return false
        }

        return !suggestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var requestUnavailableReason: String? {
        if isLoading {
            return "Already thinking."
        }

        guard bundleIdentifier != nil else {
            return "Open a writing app first."
        }

        switch supportStatus {
        case let .supported(profile):
            if profile.isSensitive {
                return "Sensitive apps stay off here."
            }
        case .denylisted:
            return "This app stays off because it can expose secrets or shell input."
        case .unsupported:
            break
        }

        guard runtimeReport.allowsSuggestions else {
            return "Local model is \(runtimeReport.summary)."
        }

        guard let context else {
            return "No focused text field was readable."
        }

        if context.isSecure {
            return "Secure fields stay off."
        }

        if case .unsupported = supportStatus,
           context.selectedTextLength == 0 {
            return "Select text first; unsupported apps do not read the whole field."
        }

        guard context.hasRequestText else {
            return "Type or select a little text first."
        }

        return nil
    }

    var statusText: String {
        if !statusMessage.isEmpty {
            return statusMessage
        }

        if let requestUnavailableReason {
            return "Not ready: \(requestUnavailableReason)"
        }

        return "Ready: press Suggest. Copy writes to clipboard only."
    }
}

@MainActor
final class CommandContextPanelController: NSObject {
    private let panel: NSPanel
    private let appLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")
    private let contextLabel = NSTextField(labelWithString: "")
    private let privacyLabel = NSTextField(labelWithString: "")
    private let normalTypingLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let suggestionView = NSTextView(frame: .zero)
    private let requestButton = NSButton(title: "Suggest", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    private let requestSuggestion: () -> Void
    private let copySuggestion: () -> Void
    private let closePanel: () -> Void

    init(
        requestSuggestion: @escaping () -> Void,
        copySuggestion: @escaping () -> Void,
        closePanel: @escaping () -> Void
    ) {
        self.requestSuggestion = requestSuggestion
        self.copySuggestion = copySuggestion
        self.closePanel = closePanel

        let contentView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 560, height: 380))
        contentView.material = .contentBackground
        contentView.blendingMode = .behindWindow
        contentView.state = .active

        panel = NSPanel(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Command Context"
        panel.contentView = contentView
        panel.isReleasedWhenClosed = false
        panel.contentMinSize = NSSize(width: 520, height: 340)

        super.init()

        buildContent(in: contentView)
    }

    var isShowing: Bool {
        panel.isVisible
    }

    func show(state: CommandContextPanelState) {
        refresh(state: state)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(state: CommandContextPanelState) {
        appLabel.stringValue = state.appText
        pathLabel.stringValue = state.pathText
        contextLabel.stringValue = state.contextText
        privacyLabel.stringValue = state.privacyText
        normalTypingLabel.stringValue = state.normalTypingText
        statusLabel.stringValue = state.statusText
        suggestionView.string = state.suggestionDisplayText
        requestButton.title = state.requestButtonTitle
        requestButton.isEnabled = state.canRequestSuggestion
        copyButton.isEnabled = state.canCopySuggestion
    }

    private func buildContent(in contentView: NSView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Command Context")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)

        [appLabel, pathLabel, contextLabel, privacyLabel, normalTypingLabel, statusLabel].forEach {
            configureSecondaryLabel($0)
        }
        appLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        appLabel.textColor = .labelColor
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)

        suggestionView.isEditable = false
        suggestionView.isSelectable = true
        suggestionView.drawsBackground = true
        suggestionView.backgroundColor = .textBackgroundColor
        suggestionView.font = NSFont.systemFont(ofSize: 14)
        suggestionView.textContainerInset = NSSize(width: 8, height: 8)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = suggestionView
        scrollView.heightAnchor.constraint(equalToConstant: 96).isActive = true

        requestButton.target = self
        requestButton.action = #selector(requestSuggestionControl)
        requestButton.bezelStyle = .rounded
        requestButton.toolTip = "Asks the local model for a suggestion using the current field context."
        copyButton.target = self
        copyButton.action = #selector(copySuggestionControl)
        copyButton.bezelStyle = .rounded
        copyButton.toolTip = "Copies the suggestion to the clipboard without writing into the app."
        closeButton.target = self
        closeButton.action = #selector(closeControl)
        closeButton.bezelStyle = .rounded

        [
            title,
            appLabel,
            pathLabel,
            contextLabel,
            privacyLabel,
            normalTypingLabel,
            scrollView,
            statusLabel,
            makeButtonRow([requestButton, copyButton, closeButton])
        ].forEach {
            stack.addArrangedSubview($0)
        }

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -22),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func configureSecondaryLabel(_ label: NSTextField) {
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = 500
    }

    private func makeButtonRow(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    @objc
    private func requestSuggestionControl() {
        requestSuggestion()
    }

    @objc
    private func copySuggestionControl() {
        copySuggestion()
    }

    @objc
    private func closeControl() {
        closePanel()
        panel.orderOut(nil)
    }
}
