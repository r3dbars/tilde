import SwiftUI

struct PrivacyAndDataView: View {
    @ObservedObject var model: TildeSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showIgnoredApps = false
    @State private var showLocalData = false

    var body: some View {
        Form {
            Section("Privacy & Data") {
                Text("Your screen, writing, and learning stay on this Mac.")
                Button("Apps Tilde Ignores…") { showIgnoredApps = true }
                Button("Manage Local Data…") { showLocalData = true }
            }

            Section {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 240)
        .sheet(isPresented: $showIgnoredApps) {
            IgnoredAppsView(model: model)
        }
        .sheet(isPresented: $showLocalData) {
            LocalDataView(model: model)
        }
    }
}

struct IgnoredAppsView: View {
    @ObservedObject var model: TildeSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Apps Tilde Ignores")
                .font(.title2.weight(.semibold))
            Text("Tilde never reads or suggests inside these apps.")
                .foregroundStyle(.secondary)

            if model.excludedApplications.isEmpty {
                ContentUnavailableView(
                    "No Ignored Apps",
                    systemImage: "checkmark.shield",
                    description: Text("Sensitive apps such as password managers are always ignored.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(model.excludedApplications) { application in
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
                        .help("Stop ignoring this app")
                    }
                }
            }

            HStack {
                Button("Add App…") { model.chooseApplicationToExclude() }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460, height: 400)
    }
}

struct LocalDataView: View {
    @ObservedObject var model: TildeSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDeleteLearning = false
    @State private var confirmDeleteOCREvaluation = false

    var body: some View {
        Form {
            Section("Personalization Data") {
                LabeledContent("Stored on this Mac", value: model.learningDataSize)
                Button("Delete Personalization Data…", role: .destructive) {
                    confirmDeleteLearning = true
                }
                .disabled(model.isDeletingLearningData || model.learningDataSize == "No learning data")
            }

            if model.hasLocalOCREvaluationSamples {
                Section("Developer Evaluation Data") {
                    LabeledContent("Stored on this Mac", value: model.localOCREvaluationData)
                    Button("Reveal in Finder") { model.revealLocalOCREvaluationData() }
                    Button("Delete Evaluation Data…", role: .destructive) {
                        confirmDeleteOCREvaluation = true
                    }
                    .disabled(model.isDeletingOCREvaluationData)
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: model.hasLocalOCREvaluationSamples ? 360 : 260)
        .confirmationDialog(
            "Delete all personalization data?",
            isPresented: $confirmDeleteLearning
        ) {
            Button("Delete", role: .destructive) { model.deleteLearningData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your encrypted writing history, the local word diary, and learning signals. Tilde and its model are preserved.")
        }
        .confirmationDialog(
            "Delete all evaluation data?",
            isPresented: $confirmDeleteOCREvaluation
        ) {
            Button("Delete", role: .destructive) { model.deleteLocalOCREvaluationData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes locally stored raw OCR evaluation samples.")
        }
    }
}

struct TroubleshootingView: View {
    @ObservedObject var model: TildeSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDeleteModel = false

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Tilde", value: model.simpleStatusText)
                LabeledContent("Screen Access", value: model.screenAccessNeedsAttention ? "Needs attention" : "Ready")
                if model.screenAccessNeedsAttention {
                    Button("Fix Screen Access") { model.enableScreenAccess() }
                }
            }

            Section("Model") {
                LabeledContent(model.modelDescription, value: model.modelStatusText)
                if let progress = model.modelProgress {
                    ProgressView(value: progress.fraction)
                    Text(progress.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Redownload Model…", role: .destructive) {
                    confirmDeleteModel = true
                }
                .disabled(!model.canDeleteModel || model.isDeletingModel)
            }

            Section("Help") {
                Button("Run Setup Again…") { model.runSetupAgain() }
                Button("Export Diagnostics…") { model.exportDiagnostics() }
                LabeledContent("Version", value: model.versionText)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 500)
        .confirmationDialog(
            "Redownload the local model?",
            isPresented: $confirmDeleteModel
        ) {
            Button("Redownload", role: .destructive) { model.deleteModel() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Tilde will remove the current model and open setup to download it again. Your writing and personalization data stay on this Mac.")
        }
    }
}
