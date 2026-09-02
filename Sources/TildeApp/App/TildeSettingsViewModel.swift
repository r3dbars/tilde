import AppKit
import TildeCore
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct ExcludedApplication: Identifiable, Equatable {
    let bundleIdentifier: String
    let name: String

    var id: String { bundleIdentifier }
}

enum TildeModelPresentation {
    static let name = "Gemma 4 E2B"
    static let approximateSize = "about 3.43 GB"
    static let description = "\(name) · \(approximateSize)"
}

/// The two keys that accept a suggestion, written once and shown everywhere
/// the product explains itself. Tab has always been documented; the tilde
/// key — the product's namesake, `GhostInputController`'s key code 50 — was
/// implemented and never mentioned anywhere a user would look.
enum TildeAcceptKeys {
    /// "the key above Tab" is the description that survives layout
    /// differences: key code 50 sits at the top-left on both ANSI and ISO
    /// keyboards, but only ANSI prints `~` on it.
    static let wholeSuggestionKeyDescription = "~ (the key above Tab)"
    static let wordShortcut = "Tab"
    static let wholeSuggestionShortcut = "~"
    static let wordLabel = "Accept the next word"
    static let wholeSuggestionLabel = "Accept the whole suggestion"
    static let summary =
        "Tab accepts the next word. \(wholeSuggestionKeyDescription) accepts the whole suggestion."
    static let readySummary = "Start typing anywhere. \(summary)"
}

enum TildeSettingsPresentation {
    static func simpleStatusText(for statusText: String) -> String {
        switch statusText {
        case "Tilde is Ready": "Ready"
        case "Tilde is Paused": "Paused"
        case "Model is Loading": "Getting ready…"
        default: "Needs attention"
        }
    }
}

struct TildeModelDownloadProgress: Equatable {
    let receivedBytes: Int64
    let totalBytes: Int64

    var fraction: Double? {
        guard totalBytes > 0 else { return nil }
        return min(1, max(0, Double(receivedBytes) / Double(totalBytes)))
    }

    var detail: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: max(0, receivedBytes))) of \(formatter.string(fromByteCount: max(0, totalBytes)))"
    }
}

@MainActor
final class TildeSettingsViewModel: ObservableObject {
    @Published private(set) var statusText = "Model is Loading"
    @Published private(set) var modelState: ModelState = .checking
    @Published private(set) var suggestionsEnabled = true
    @Published private(set) var launchAtLoginEnabled = true
    @Published private(set) var screenMemoryEnabled = true
    @Published private(set) var screenRecordingGranted = false
    @Published private(set) var personalizationEnabled = false
    @Published private(set) var selectedProductionModel: TildeModelChoice?
    @Published private(set) var selectedPreviewModel: PreviewModelChoice?
    @Published private(set) var hasLocalOCREvaluationSamples = false
    @Published private(set) var localOCREvaluationData = "No samples"
    @Published private(set) var excludedApplications: [ExcludedApplication] = []
    @Published private(set) var learningDataSize = "No learning data"
    @Published private(set) var message: String?
    @Published private(set) var isDeletingLearningData = false
    @Published private(set) var isDeletingModel = false
    @Published private(set) var isDeletingOCREvaluationData = false

    private weak var appDelegate: AppDelegate?
    private let personalHistory: PersonalHistoryController
    private let settings: TildeSettings
    private var localOCREvaluationSummaryGeneration: UInt64 = 0

    /// `appDelegate` is optional and `settings` is injectable so this model
    /// can be exercised without a running app: every use of the delegate is
    /// already optional-chained, and a test that wrote through the real
    /// `TildeSettings()` would edit the owner's own daily driver.
    init(
        appDelegate: AppDelegate?,
        personalHistory: PersonalHistoryController,
        settings: TildeSettings = TildeSettings()
    ) {
        self.appDelegate = appDelegate
        self.personalHistory = personalHistory
        self.settings = settings
        refresh()
    }

    var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    var modelDescription: String {
        appDelegate?.modelDescription() ?? TildeModelPresentation.description
    }

    var showsPreviewModelPicker: Bool {
        TildeProductProfile.current == .modelPreview
    }

    var showsProductionModelPicker: Bool {
        TildeProductProfile.current == .production
    }

    var simpleStatusText: String {
        TildeSettingsPresentation.simpleStatusText(for: statusText)
    }

    var screenAccessNeedsAttention: Bool {
        !screenMemoryEnabled || !screenRecordingGranted
    }

    var modelProgress: TildeModelDownloadProgress? {
        guard case let .downloading(receivedBytes, totalBytes) = modelState else { return nil }
        return TildeModelDownloadProgress(receivedBytes: receivedBytes, totalBytes: totalBytes)
    }

    var modelStatusText: String {
        switch modelState {
        case .checking: "Checking…"
        case .missing: "Not downloaded"
        case .downloading: "Downloading…"
        case .verifying: "Checking download…"
        case .ready: "Ready"
        case let .failed(failure): modelFailureDescription(failure)
        }
    }

    var canDeleteModel: Bool {
        switch modelState {
        case .checking, .missing:
            return false
        case .downloading, .verifying, .ready, .failed:
            return true
        }
    }

    func refresh() {
        modelState = appDelegate?.modelState() ?? .missing
        suggestionsEnabled = settings.suggestionsEnabled
        launchAtLoginEnabled = settings.launchAtLoginEnabled
        screenMemoryEnabled = settings.screenMemoryEnabled
        screenRecordingGranted = ScreenRecordingPermission.isGranted()
        personalizationEnabled = personalHistory.isEnabled
        selectedProductionModel = appDelegate?.selectedProductionModel()
        selectedPreviewModel = appDelegate?.selectedPreviewModel()
        Task { [weak self] in
            await self?.refreshLocalOCREvaluationSummary()
        }
        excludedApplications = personalHistory.excludedApps
            .map(Self.describeApplication)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        statusText = appDelegate?.applicationState().statusText ?? "Tilde Needs Attention"
        message = nil

        Task { [weak self, personalHistory] in
            guard let self else { return }
            let summary = await personalHistory.summary()
            guard !Task.isCancelled else { return }
            let bytes = (summary?.approximateBytes ?? 0) + TildeLocalOutcomeStores.approximateBytes()
            if bytes > 0 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB, .useGB]
                formatter.countStyle = .file
                self.learningDataSize = formatter.string(fromByteCount: bytes)
            } else {
                self.learningDataSize = "No learning data"
            }
        }
    }

    func refreshLocalOCREvaluationSummary() async {
        localOCREvaluationSummaryGeneration &+= 1
        let generation = localOCREvaluationSummaryGeneration
        let summary = await Task.detached(priority: .utility) {
            LocalOCREvaluationStore.shared.summary()
        }.value
        guard !Task.isCancelled,
              generation == localOCREvaluationSummaryGeneration else { return }
        applyLocalOCREvaluationSummary(summary)
    }

    private func applyLocalOCREvaluationSummary(_ evaluationSummary: LocalOCREvaluationSummary) {
        // A non-empty oversized/corrupt corpus still contains raw text and
        // must keep Reveal/Delete available even when no valid sample count
        // can be reported.
        hasLocalOCREvaluationSamples = evaluationSummary.sampleCount > 0
            || evaluationSummary.approximateBytes > 0
        if evaluationSummary.sampleCount == 0 {
            localOCREvaluationData = "No samples"
        } else {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            localOCREvaluationData = "\(evaluationSummary.sampleCount) samples · \(formatter.string(fromByteCount: evaluationSummary.approximateBytes))"
        }
    }

    func setSuggestionsEnabled(_ enabled: Bool) {
        settings.suggestionsEnabled = enabled
        suggestionsEnabled = enabled
        statusText = appDelegate?.applicationState().statusText ?? statusText
    }

    func setPreviewModel(_ choice: PreviewModelChoice) {
        guard showsPreviewModelPicker, choice != selectedPreviewModel else { return }
        selectedPreviewModel = choice
        message = "Switching to \(choice.shortName)…"
        appDelegate?.selectPreviewModel(choice)
    }

    func setProductionModel(_ choice: TildeModelChoice) {
        guard showsProductionModelPicker, choice != selectedProductionModel else { return }
        selectedProductionModel = choice
        message = "Switching to \(choice.shortName)…"
        appDelegate?.selectProductionModel(choice)
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

    /// The Screen Memory covenant's mandatory master toggle. Off is a real
    /// off: the setting is written first, then the app is told, so the
    /// capture service drops the snapshots it is still holding rather than
    /// serving them for the rest of the staleness window.
    func setScreenMemoryEnabled(_ enabled: Bool) {
        settings.screenMemoryEnabled = enabled
        screenMemoryEnabled = enabled
        appDelegate?.screenMemoryEnabledDidChange(enabled)
        screenRecordingGranted = ScreenRecordingPermission.isGranted()
        statusText = appDelegate?.applicationState().statusText ?? statusText
    }

    /// Honest copy, and the honest part is that this is not a "less
    /// context" switch: with Screen Memory off, Tilde answers every
    /// completion request with silence (`ScreenMemoryStatus`). Saying only
    /// that it "suggests less" would be a comfortable lie.
    var screenMemoryExplanation: String {
        screenMemoryEnabled
            ? "Tilde reads the text on your screen so it knows what you are replying to. It stays on this Mac. Turn this off and Tilde cannot see what you are replying to — it stops suggesting entirely until you turn it back on."
            : "Tilde cannot see what you are replying to, so it is not suggesting anything. Turn this back on to get suggestions again."
    }

    func enableScreenAccess() {
        setScreenMemoryEnabled(true)
        if !ScreenRecordingPermission.isGranted(), !ScreenRecordingPermission.request() {
            openScreenRecordingSettings()
        }
        screenRecordingGranted = ScreenRecordingPermission.isGranted()
        statusText = appDelegate?.applicationState().statusText ?? statusText
    }

    func openScreenRecordingSettings() {
        NSWorkspace.shared.open(ScreenRecordingPermission.systemSettingsURL)
    }

    func runSetupAgain() {
        appDelegate?.showSetup()
    }

    func setPersonalizationEnabled(_ enabled: Bool) {
        personalHistory.isEnabled = enabled
        personalizationEnabled = enabled
    }

    func revealLocalOCREvaluationData() {
        let location = LocalOCREvaluationStore.shared.location
        guard FileManager.default.fileExists(atPath: location.path) else {
            message = "No OCR evaluation samples are available yet."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([location])
    }

    func deleteLocalOCREvaluationData() {
        guard !isDeletingOCREvaluationData else { return }
        isDeletingOCREvaluationData = true
        localOCREvaluationSummaryGeneration &+= 1
        settings.localOCREvaluationEnabled = false
        LocalOCREvaluationStore.shared.flush()
        if LocalOCREvaluationStore.shared.deleteAll() {
            hasLocalOCREvaluationSamples = false
            localOCREvaluationData = "No samples"
            message = "OCR evaluation samples were deleted and recording was turned off."
        } else {
            message = "OCR evaluation samples could not be deleted."
        }
        isDeletingOCREvaluationData = false
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
                TildeLocalOutcomeStores.deleteAll()
                self.learningDataSize = "No learning data"
                self.personalizationEnabled = false
                self.message = "Learning data was deleted."
            } catch {
                self.message = "Learning data could not be deleted. Quit and reopen Tilde, then try again."
            }
            self.isDeletingLearningData = false
        }
    }

    func deleteModel() {
        guard !isDeletingModel else { return }
        guard let appDelegate else {
            message = "The model could not be deleted. Quit and reopen Tilde, then try again."
            return
        }
        isDeletingModel = true
        message = nil
        appDelegate.deleteModel()
        isDeletingModel = false
        refresh()
        message = "Model deletion started. Setup will reopen when it is complete."
    }

    func exportDiagnostics() {
        DiagnosticsLog.shared.flush()
        let source = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
            .appendingPathComponent(TildeProductProfile.current.supportDirectoryName)
            .appendingPathComponent("diagnostics.log")
        guard FileManager.default.fileExists(atPath: source.path) else {
            message = "No diagnostics are available yet."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export \(TildeProductProfile.current.displayName) Diagnostics"
        panel.nameFieldStringValue = "\(TildeProductProfile.current.displayName) Diagnostics.log"
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

    private func modelFailureDescription(_ failure: ModelFailure) -> String {
        switch failure {
        case .offline: "Download paused — connection unavailable"
        case .insufficientDiskSpace: "Not enough disk space"
        case .serverRejectedRequest: "Model host rejected the download"
        case .checksumMismatch: "Integrity check failed"
        case .invalidModel: "Invalid model download"
        case .installationFailed: "Model installation failed"
        }
    }
}
