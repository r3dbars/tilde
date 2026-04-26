import AppKit
import AutocompleteLabCore

@MainActor
final class DiagnosticsWindowController {
    private let window: NSWindow
    private let textView: NSTextView

    init() {
        textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 620, height: 420))
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView

        window = NSWindow(
            contentRect: scrollView.frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Autocomplete Diagnostics"
        window.contentView = scrollView
    }

    func show(
        diagnostics: FocusedTextDiagnostics?,
        profile: CompatibilityProfile?,
        compatibilityStatus: CompatibilitySupportStatus,
        appEnabled: Bool,
        appTrusted: Bool,
        runtimeReport: RuntimeReadinessReport,
        modelDirectoryPath: String,
        recentEvents: [String]
    ) {
        var sections: [String] = []

        sections.append("Permission: Accessibility \(appTrusted ? "granted" : "missing")")
        sections.append(
            """
            Local model: \(runtimeReport.summary)
              stage: \(runtimeReport.stage.rawValue)
              action: \(runtimeReport.action.displayName)
              detail: \(runtimeReport.detail ?? "none")
            """
        )
        sections.append("Model folder: \(modelDirectoryPath)")
        sections.append("Compatibility: \(compatibilityStatus.summary)")
        sections.append("Current app enabled: \(appEnabled)")

        if let profile {
            sections.append(
                """
                Compatibility profile:
                  app: \(profile.displayName) (\(profile.bundleIdentifier))
                  render mode: \(profile.renderMode.rawValue)
                  insertion mode: \(profile.insertionMode.rawValue)
                  fallback render: \(profile.fallbackRenderMode?.rawValue ?? "none")
                  fallback insertion: \(profile.fallbackInsertionMode?.rawValue ?? "none")
                  field identity: \(profile.fieldIdentityMode.rawValue)
                  one-word accept: \(profile.supportsOneWordAcceptance)
                  full accept: \(profile.supportsFullAcceptance)
                  Esc suppression: \(profile.suppressesUntilBlurAfterEscape)
                  sensitive: \(profile.isSensitive)
                  debug summary: \(profile.debugSummary)
                  notes: \(profile.notes)
                """
            )
        } else {
            sections.append("Compatibility profile: not allowed or not recognized")
        }

        sections.append(diagnostics?.summary ?? "Focused text diagnostics: unavailable")

        if recentEvents.isEmpty {
            sections.append("Recent events: unavailable")
        } else {
            sections.append(
                """
                Recent events:
                \(recentEvents.map { "  \($0)" }.joined(separator: "\n"))
                """
            )
        }

        textView.string = sections.joined(separator: "\n\n")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
