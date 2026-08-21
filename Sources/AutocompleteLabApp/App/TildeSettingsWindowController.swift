import AppKit
import SwiftUI

@MainActor
final class TildeSettingsWindowController: NSWindowController, NSWindowDelegate {
    private let settingsModel: TildeSettingsViewModel
    private let progressModel: YourTildeViewModel
    private var settingsRefreshTimer: Timer?
    private var progressRefreshTimer: Timer?

    init(appDelegate: AppDelegate, personalHistory: PersonalHistoryController) {
        settingsModel = TildeSettingsViewModel(
            appDelegate: appDelegate,
            personalHistory: personalHistory
        )
        progressModel = YourTildeViewModel(personalHistory: personalHistory)
        let rootView = TildeSettingsView(
            model: settingsModel,
            progressModel: progressModel
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 720),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tilde"
        window.contentViewController = NSHostingController(rootView: rootView)
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show() {
        settingsModel.refresh()
        progressModel.refresh()
        startRefreshing()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh() {
        guard window?.isVisible == true else { return }
        settingsModel.refresh()
        progressModel.refresh()
    }

    func windowWillClose(_ notification: Notification) {
        settingsRefreshTimer?.invalidate()
        settingsRefreshTimer = nil
        progressRefreshTimer?.invalidate()
        progressRefreshTimer = nil
    }

    private func startRefreshing() {
        guard settingsRefreshTimer == nil, progressRefreshTimer == nil else { return }
        let settingsTimer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.settingsModel.refresh() }
        }
        let progressTimer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.progressModel.refresh() }
        }
        RunLoop.main.add(settingsTimer, forMode: .common)
        RunLoop.main.add(progressTimer, forMode: .common)
        settingsRefreshTimer = settingsTimer
        progressRefreshTimer = progressTimer
    }
}

private struct TildeSettingsView: View {
    @ObservedObject var model: TildeSettingsViewModel
    @ObservedObject var progressModel: YourTildeViewModel

    @State private var confirmEnablePersonalization = false
    @State private var showIgnoredApps = false
    @State private var showLocalData = false
    @State private var showTroubleshooting = false

    var body: some View {
        Form {
            Section("Your Tilde") {
                YourTildeSummaryView(model: progressModel)
            }

            Section("Tilde") {
                Toggle("Tilde", isOn: Binding(
                    get: { model.suggestionsEnabled },
                    set: { model.setSuggestionsEnabled($0) }
                ))

                Toggle("Open at Login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLoginEnabled($0) }
                ))

                LabeledContent("Status", value: model.simpleStatusText)

                if model.screenAccessNeedsAttention {
                    HStack {
                        LabeledContent("Screen Access", value: "Needs attention")
                        Button("Fix Access") { model.enableScreenAccess() }
                    }
                } else {
                    LabeledContent("Screen Access", value: "Ready")
                }
            }

            Section("Personalization") {
                Toggle("Personalization", isOn: Binding(
                    get: { model.personalizationEnabled },
                    set: { enabled in
                        if enabled { confirmEnablePersonalization = true }
                        else { model.setPersonalizationEnabled(false) }
                    }
                ))

                Text("Tilde learns your writing patterns and uses them to improve suggestions.")
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Text("Your screen, writing, and learning stay on this Mac.")

                Button("Apps Tilde Ignores…") { showIgnoredApps = true }
                Button("Manage Local Data…") { showLocalData = true }
            }

            Section {
                Button("Troubleshooting…") { showTroubleshooting = true }
            } footer: {
                Text("Tilde \(model.versionText)")
            }

            if let message = model.message {
                Section {
                    Text(message)
                        .foregroundStyle(message.contains("could not") ? .red : .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(minWidth: 500, minHeight: 620)
        .sheet(isPresented: $showIgnoredApps) {
            IgnoredAppsView(model: model)
        }
        .sheet(isPresented: $showLocalData) {
            LocalDataView(model: model)
        }
        .sheet(isPresented: $showTroubleshooting) {
            TroubleshootingView(model: model)
        }
        .confirmationDialog(
            "Turn on Personalization?",
            isPresented: $confirmEnablePersonalization
        ) {
            Button("Turn On") { model.setPersonalizationEnabled(true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Tilde will store encrypted writing history on this Mac and use it to improve suggestions. Nothing is uploaded.")
        }
    }
}
