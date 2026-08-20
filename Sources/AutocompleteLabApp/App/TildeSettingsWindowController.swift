import AppKit
import SwiftUI

@MainActor
final class TildeSettingsWindowController: NSWindowController, NSWindowDelegate {
    private let model: TildeSettingsViewModel

    init(appDelegate: AppDelegate, personalHistory: PersonalHistoryController) {
        model = TildeSettingsViewModel(appDelegate: appDelegate, personalHistory: personalHistory)
        let rootView = TildeSettingsView(model: model)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 820),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tilde Settings"
        window.contentViewController = NSHostingController(rootView: rootView)
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show() {
        model.refresh()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh() {
        model.refresh()
    }
}

private struct TildeSettingsView: View {
    @ObservedObject var model: TildeSettingsViewModel
    @State private var confirmDisableScreenMemory = false
    @State private var confirmEnableLearning = false
    @State private var confirmDeleteLearning = false
    @State private var confirmEnableOCREvaluation = false
    @State private var confirmDeleteOCREvaluation = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Tilde On", isOn: Binding(
                    get: { model.suggestionsEnabled },
                    set: { model.setSuggestionsEnabled($0) }
                ))

                Toggle("Launch Tilde at Login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLoginEnabled($0) }
                ))

                Toggle("Screen Memory", isOn: Binding(
                    get: { model.screenMemoryEnabled },
                    set: { enabled in
                        if enabled { model.setScreenMemoryEnabled(true) }
                        else { confirmDisableScreenMemory = true }
                    }
                ))

                if model.screenMemoryEnabled, !model.screenRecordingGranted {
                    HStack {
                        Text("Screen Recording permission is required for suggestions.")
                            .foregroundStyle(.red)
                        Spacer()
                        Button("Open System Settings") { model.openScreenRecordingSettings() }
                    }
                }

                LabeledContent("Status", value: model.statusText)
            }

            Section {
                if model.excludedApplications.isEmpty {
                    Text("No excluded applications")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.excludedApplications) { application in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(application.name)
                                Text(application.bundleIdentifier)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                model.removeExcludedApplication(application)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .help("Remove application")
                        }
                    }
                }

                Button("Add Application…") { model.chooseApplicationToExclude() }
            } header: {
                Text("Apps")
            } footer: {
                Text("Tilde never observes or suggests inside excluded applications. Screen capture also pauses while an excluded app is visible.")
            }

            Section("Privacy") {
                Text("Your writing and personal learning data stay on this Mac.")

                Toggle("Personal Learning", isOn: Binding(
                    get: { model.personalHistoryEnabled },
                    set: { enabled in
                        if enabled { confirmEnableLearning = true }
                        else { model.setPersonalHistoryEnabled(false) }
                    }
                ))

                if model.personalHistoryEnabled {
                    Toggle("Use Personal Suggestions", isOn: Binding(
                        get: { model.personalSuggestionsEnabled },
                        set: { model.setPersonalSuggestionsEnabled($0) }
                    ))
                }

                LabeledContent("Learning data", value: model.learningDataSize)

                Button("Delete Learning Data…", role: .destructive) {
                    confirmDeleteLearning = true
                }
                .disabled(model.isDeletingLearningData || model.learningDataSize == "No learning data")

                LabeledContent("Model", value: model.modelDescription)
                Button("Delete Model…") {}
                    .disabled(true)
            }

            if model.localOCREvaluationAvailable {
                Section("OCR Evaluation — Development") {
                    Toggle("Record Raw Paired OCR Samples", isOn: Binding(
                        get: { model.localOCREvaluationEnabled },
                        set: { enabled in
                            if enabled { confirmEnableOCREvaluation = true }
                            else { model.setLocalOCREvaluationEnabled(false) }
                        }
                    ))

                    Text("Runs full OCR beside incremental OCR on the same frame and stores both raw outputs locally. This may capture sensitive text and slow Tilde while enabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LabeledContent("Evaluation data", value: model.localOCREvaluationData)
                    Button("Reveal Evaluation Data") { model.revealLocalOCREvaluationData() }
                        .disabled(model.localOCREvaluationData == "No samples")
                    Button("Delete Evaluation Data…", role: .destructive) {
                        confirmDeleteOCREvaluation = true
                    }
                    .disabled(model.isDeletingOCREvaluationData || model.localOCREvaluationData == "No samples")
                }
            }

            Section("Support") {
                LabeledContent("Version", value: model.versionText)
                Button("Export Diagnostics…") { model.exportDiagnostics() }
                Button("Check for Updates…") {}
                    .disabled(true)
                Button("Run Setup Again…") { model.runSetupAgain() }
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
        .frame(minWidth: 500, minHeight: 680)
        .confirmationDialog(
            "Turn off Screen Memory?",
            isPresented: $confirmDisableScreenMemory
        ) {
            Button("Turn Off", role: .destructive) { model.setScreenMemoryEnabled(false) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Screen Memory is required for Tilde suggestions. Turning it off pauses Tilde.")
        }
        .confirmationDialog(
            "Turn on Personal Learning?",
            isPresented: $confirmEnableLearning
        ) {
            Button("Turn On") { model.setPersonalHistoryEnabled(true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Tilde will store encrypted writing history on this Mac to improve suggestions. Nothing is uploaded.")
        }
        .confirmationDialog(
            "Delete all learning data?",
            isPresented: $confirmDeleteLearning
        ) {
            Button("Delete", role: .destructive) { model.deleteLearningData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes encrypted writing history, its Keychain key, and learning signals. The app and bundled model are preserved.")
        }
        .confirmationDialog(
            "Record raw OCR samples?",
            isPresented: $confirmEnableOCREvaluation
        ) {
            Button("Start Recording") { model.setLocalOCREvaluationEnabled(true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Visible text from your screen will be stored unredacted on this Mac in an owner-only file. Collection is limited to this development build and the newest 100 samples or 10 MB.")
        }
        .confirmationDialog(
            "Delete all OCR evaluation samples?",
            isPresented: $confirmDeleteOCREvaluation
        ) {
            Button("Delete and Turn Off", role: .destructive) {
                model.deleteLocalOCREvaluationData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the local raw OCR evaluation corpus and disables further recording.")
        }
    }
}
