import AppKit
import SwiftUI

/// The Tilde window, minimal-first (owner wireframe, 2026-07-26): one pane —
/// hero number, speed subline, four toggles, one honest privacy sentence.
/// Native controls, system font, follows light/dark. Nothing else.
struct TildeMinimalView: View {
    @State private var today = TildeStats.today()
    @State private var lifetime = TildeStats.lifetimeWordsAccepted()

    @AppStorage("VisiblePageContextEnabled") private var screenAware = true
    @AppStorage("tilde.suggestionsEnabled") private var suggestions = true
    @AppStorage("tilde.soundsEnabled") private var sounds = true
    @AppStorage("tilde.learningEnabled") private var learning = true

    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("\(lifetime)")
                    .font(.system(size: 32, weight: .medium))
                Text("words written for you")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(subline)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider().padding(.horizontal, 14)

            VStack(spacing: 2) {
                Toggle("Suggestions", isOn: $suggestions)
                Toggle("Screen-aware", isOn: $screenAware)
                Toggle("Sounds", isOn: $sounds)
                Toggle("Learns from typing", isOn: $learning)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 14)

            HStack {
                Text("Everything stays on this Mac")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Data…") {
                    NSWorkspace.shared.open(
                        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                            .appendingPathComponent("SteadyType")
                    )
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 300)
        .onReceive(timer) { _ in
            today = TildeStats.today()
            lifetime = TildeStats.lifetimeWordsAccepted()
        }
        .onChange(of: suggestions) { _, on in Self.setIMEFlag(on ? 0 : .greatestFiniteMagnitude, key: "GhostPausedUntil") }
        .onChange(of: sounds) { _, on in Self.setIMEBool(on, key: "GhostSoundsEnabled") }
        .onChange(of: learning) { _, on in Self.setIMEBool(on, key: "GhostUsageCaptureEnabled") }
    }

    private var subline: String {
        var parts = ["today: \(today.wordsAccepted)"]
        if today.shareOfTyping > 0 { parts.append("\(today.shareOfTyping)% of your typing") }
        if today.wordsPerMinute > 0, today.fingersPerMinute > 0 {
            parts.append("\(today.wordsPerMinute) wpm with Tilde · \(today.fingersPerMinute) without")
        }
        return parts.joined(separator: " · ")
    }

    /// The keyboard reads its own defaults domain; the window writes there.
    private static func setIMEBool(_ value: Bool, key: String) {
        UserDefaults(suiteName: "bar.r3d.inputmethod.InlineGhost")?.set(value, forKey: key)
    }
    private static func setIMEFlag(_ value: Double, key: String) {
        UserDefaults(suiteName: "bar.r3d.inputmethod.InlineGhost")?.set(value, forKey: key)
    }
}

/// Window plumbing: one small fixed window, shown from the menu.
@MainActor
final class TildeWindowHost {
    static let shared = TildeWindowHost()
    private var window: NSWindow?

    func show() {
        if let w = window { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let hosting = NSHostingController(rootView: TildeMinimalView())
        let w = NSWindow(contentViewController: hosting)
        w.title = "Tilde"
        w.styleMask = [.titled, .closable]
        w.setContentSize(hosting.view.fittingSize)
        w.isReleasedWhenClosed = false
        w.center()
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
