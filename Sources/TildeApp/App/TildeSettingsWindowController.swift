import AppKit
import TildeCore
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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 660),
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
    @State private var showPrivacyAndData = false
    @State private var showTroubleshooting = false

    var body: some View {
        Form {
            Section("Your Tilde") {
                YourTildeSummaryView(model: progressModel)
            }

            Section("Settings") {
                VStack(alignment: .leading, spacing: 5) {
                    Toggle("Tilde", isOn: Binding(
                        get: { model.suggestionsEnabled },
                        set: { model.setSuggestionsEnabled($0) }
                    ))

                    if model.screenAccessNeedsAttention {
                        HStack {
                            Text("Screen Access is required")
                                .foregroundStyle(.orange)
                            Spacer()
                            Button("Fix Access…") { model.enableScreenAccess() }
                        }
                        .font(.caption)
                    } else {
                        Text(model.simpleStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if model.showsPreviewModelPicker {
                    VStack(alignment: .leading, spacing: 5) {
                        Picker("Model", selection: Binding(
                            get: { model.selectedPreviewModel ?? .qwen35B9B },
                            set: { model.setPreviewModel($0) }
                        )) {
                            ForEach(PreviewModelChoice.allCases, id: \.self) { choice in
                                Text(choice.displayName).tag(choice)
                            }
                        }

                        Text("Changing models restarts this preview. Your normal Tilde app is untouched.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Toggle("Start Tilde when I log in", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLoginEnabled($0) }
                ))

                VStack(alignment: .leading, spacing: 5) {
                    Toggle("Personalized suggestions", isOn: Binding(
                        get: { model.personalizationEnabled },
                        set: { enabled in
                            if enabled { confirmEnablePersonalization = true }
                            else { model.setPersonalizationEnabled(false) }
                        }
                    ))

                    Text("Learns from your writing on this Mac to improve suggestions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                SettingsDestinationRow("Privacy & Data") { showPrivacyAndData = true }
                SettingsDestinationRow("Help & Troubleshooting") { showTroubleshooting = true }
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
        .sheet(isPresented: $showPrivacyAndData) {
            PrivacyAndDataView(model: model)
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

private struct SettingsDestinationRow: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens \(title.lowercased())")
    }
}
