import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct ExcludedApplication: Identifiable, Equatable {
    let bundleIdentifier: String
    let name: String

    var id: String { bundleIdentifier }
}

@MainActor
final class TildeSettingsViewModel: ObservableObject {
    @Published private(set) var statusText = "Model is Loading"
    @Published private(set) var suggestionsEnabled = true
    @Published private(set) var launchAtLoginEnabled = true
    @Published private(set) var screenMemoryEnabled = true
    @Published private(set) var screenRecordingGranted = false
    @Published private(set) var personalHistoryEnabled = false
    @Published private(set) var personalSuggestionsEnabled = false
    @Published private(set) var excludedApplications: [ExcludedApplication] = []
    @Published private(set) var learningDataSize = "No learning data"
    @Published private(set) var message: String?
    @Published private(set) var isDeletingLearningData = false

    private weak var appDelegate: AppDelegate?
    private let personalHistory: PersonalHistoryController
    private let settings = TildeSettings()

    init(appDelegate: AppDelegate, personalHistory: PersonalHistoryController) {
        self.appDelegate = appDelegate
        self.personalHistory = personalHistory
        refresh()
    }

    var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    var modelDescription: String { "Gemma · bundled with Tilde" }

    func refresh() {
        suggestionsEnabled = settings.suggestionsEnabled
        launchAtLoginEnabled = settings.launchAtLoginEnabled
        screenMemoryEnabled = settings.screenMemoryEnabled
        screenRecordingGranted = ScreenRecordingPermission.isGranted()
        personalHistoryEnabled = personalHistory.isEnabled
        personalSuggestionsEnabled = settings.personalSuggestionsServingEnabled
        excludedApplications = personalHistory.excludedApps
            .map(Self.describeApplication)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        statusText = appDelegate?.applicationState().statusText ?? "Tilde Needs Attention"
        message = nil

        Task { [weak self, personalHistory] in
            guard let self else { return }
            let summary = await personalHistory.summary()
            guard !Task.isCancelled else { return }
            if let summary, summary.approximateBytes > 0 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB, .useGB]
                formatter.countStyle = .file
                self.learningDataSize = formatter.string(fromByteCount: summary.approximateBytes)
            } else {
                self.learningDataSize = "No learning data"
            }
        }
    }

    func setSuggestionsEnabled(_ enabled: Bool) {
        settings.suggestionsEnabled = enabled
        suggestionsEnabled = enabled
        statusText = appDelegate?.applicationState().statusText ?? statusText
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .notRegistered {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
            settings.launchAtLoginEnabled = enabled
            launchAtLoginEnabled = enabled
            message = SMAppService.mainApp.status == .requiresApproval
                ? "Approve Tilde in System Settings › Login Items."
                : nil
        } catch {
            launchAtLoginEnabled = settings.launchAtLoginEnabled
            message = "Tilde could not update the login setting."
        }
    }

    func setScreenMemoryEnabled(_ enabled: Bool) {
        settings.screenMemoryEnabled = enabled
        screenMemoryEnabled = enabled
        if enabled, !ScreenRecordingPermission.isGranted() {
            ScreenRecordingPermission.request()
        }
        screenRecordingGranted = ScreenRecordingPermission.isGranted()
        statusText = appDelegate?.applicationState().statusText ?? statusText
    }

    func openScreenRecordingSettings() {
        NSWorkspace.shared.open(ScreenRecordingPermission.systemSettingsURL)
    }

    func setPersonalHistoryEnabled(_ enabled: Bool) {
        personalHistory.isEnabled = enabled
        personalHistoryEnabled = enabled
        if !enabled {
            settings.personalSuggestionsServingEnabled = false
            personalSuggestionsEnabled = false
        }
    }

    func setPersonalSuggestionsEnabled(_ enabled: Bool) {
        settings.personalSuggestionsServingEnabled = enabled
        personalSuggestionsEnabled = enabled
    }

    func chooseApplicationToExclude() {
        let panel = NSOpenPanel()
        panel.title = "Exclude an Application"
        panel.prompt = "Exclude"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else { return }

        var excluded = personalHistory.excludedApps
        excluded.insert(bundleIdentifier)
        personalHistory.excludedApps = excluded
        refresh()
    }

    func removeExcludedApplication(_ application: ExcludedApplication) {
        var excluded = personalHistory.excludedApps
        excluded.remove(application.bundleIdentifier)
        personalHistory.excludedApps = excluded
        refresh()
    }

    func deleteLearningData() {
        guard !isDeletingLearningData else { return }
        isDeletingLearningData = true
        message = nil
        Task { [weak self, personalHistory] in
            guard let self else { return }
            do {
                try await personalHistory.deleteAll()
                self.learningDataSize = "No learning data"
                self.personalHistoryEnabled = false
                self.personalSuggestionsEnabled = false
                self.message = "Learning data was deleted."
            } catch {
                self.message = "Learning data could not be deleted. Quit and reopen Tilde, then try again."
            }
            self.isDeletingLearningData = false
        }
    }

    func exportDiagnostics() {
        DiagnosticsLog.shared.flush()
        let source = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Tilde/diagnostics.log")
        guard FileManager.default.fileExists(atPath: source.path) else {
            message = "No diagnostics are available yet."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Tilde Diagnostics"
        panel.nameFieldStringValue = "Tilde Diagnostics.log"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            message = "Diagnostics exported."
        } catch {
            message = "Diagnostics could not be exported."
        }
    }

    private static func describeApplication(_ bundleIdentifier: String) -> ExcludedApplication {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
              let bundle = Bundle(url: url) else {
            return ExcludedApplication(bundleIdentifier: bundleIdentifier, name: bundleIdentifier)
        }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        return ExcludedApplication(bundleIdentifier: bundleIdentifier, name: name)
    }
}

