import AppKit

@MainActor
protocol AppLifecycleHandling: AnyObject {
    func prepareForLaunch()
    func startStatusMenu()
    func recordLaunchDiagnostics()
    func requestAccessibilityPermissionIfNeeded()
    func warmModelRuntime()
    func startSuggestionSummonHotKey()
    func showSettingsIfNeeded()
    func startWorkspaceObserver()
    func startSuggestionPipeline()
    func startResourceDiagnostics()
    func stopForTermination()
}

@MainActor
struct AppLifecycleInfrastructure {
    let setAccessoryApplicationPolicy: () -> Void
    let disableAutomaticTermination: () -> Void
    let beginAutomaticTerminationActivity: () -> NSObjectProtocol
    let endAutomaticTerminationActivity: (NSObjectProtocol) -> Void
    let scheduleOnMain: (@escaping @MainActor @Sendable () -> Void) -> Void

    static let live = AppLifecycleInfrastructure(
        setAccessoryApplicationPolicy: {
            NSApp.setActivationPolicy(.accessory)
        },
        disableAutomaticTermination: {
            ProcessInfo.processInfo.disableAutomaticTermination(
                AppResidencyPolicy.automaticTerminationReason
            )
        },
        beginAutomaticTerminationActivity: {
            ProcessInfo.processInfo.beginActivity(
                options: AppResidencyPolicy.activityOptions,
                reason: AppResidencyPolicy.automaticTerminationReason
            )
        },
        endAutomaticTerminationActivity: { activity in
            ProcessInfo.processInfo.endActivity(activity)
        },
        scheduleOnMain: { operation in
            DispatchQueue.main.async(execute: operation)
        }
    )
}

/// Owns application lifecycle ordering and process residency. Product state and
/// decisions remain in the handler, which keeps AppDelegate wiring thin.
@MainActor
final class AppLifecycleHost {
    private weak var handler: (any AppLifecycleHandling)?
    private let infrastructure: AppLifecycleInfrastructure
    private var automaticTerminationActivity: NSObjectProtocol?
    private var didDisableAutomaticTermination = false

    init(
        handler: any AppLifecycleHandling,
        infrastructure: AppLifecycleInfrastructure = .live
    ) {
        self.handler = handler
        self.infrastructure = infrastructure
    }

    func start() {
        keepProcessResident()
        infrastructure.setAccessoryApplicationPolicy()
        handler?.prepareForLaunch()
        handler?.startStatusMenu()
        handler?.recordLaunchDiagnostics()
        handler?.requestAccessibilityPermissionIfNeeded()
        handler?.warmModelRuntime()
        handler?.startSuggestionSummonHotKey()
        handler?.showSettingsIfNeeded()
        handler?.startWorkspaceObserver()
        handler?.startSuggestionPipeline()
        handler?.startResourceDiagnostics()
        infrastructure.scheduleOnMain { [weak self] in
            self?.keepProcessResident()
        }
    }

    func stop() {
        handler?.stopForTermination()
        if let automaticTerminationActivity {
            infrastructure.endAutomaticTerminationActivity(automaticTerminationActivity)
            self.automaticTerminationActivity = nil
        }
    }

    private func keepProcessResident() {
        if !didDisableAutomaticTermination {
            infrastructure.disableAutomaticTermination()
            didDisableAutomaticTermination = true
        }
        if automaticTerminationActivity == nil {
            automaticTerminationActivity = infrastructure.beginAutomaticTerminationActivity()
        }
    }
}
