import AppKit
import AutocompleteLabCore

enum WorkspaceObserverEvent {
    case workspaceFocusChanged(
        reason: String,
        kind: WorkspaceFocusChangePolicy.ChangeKind,
        bundleIdentifier: String?
    )
    case suggestionInterruption(SuggestionInterruptionKind)
    case screenGeometryChanged
}

@MainActor
protocol WorkspaceObserverEventHandling: AnyObject {
    func handleWorkspaceObserverEvent(_ event: WorkspaceObserverEvent)
}

/// Owns notification tokens for workspace lifecycle and screen changes. The app
/// coordinator receives typed events and keeps the focus/interruption policies.
@MainActor
final class WorkspaceObserverHost {
    private weak var handler: (any WorkspaceObserverEventHandling)?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var screenGeometryObserver: NSObjectProtocol?

    init(handler: any WorkspaceObserverEventHandling) {
        self.handler = handler
    }

    func start() {
        guard workspaceObservers.isEmpty, screenGeometryObserver == nil else {
            return
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            workspaceCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let bundleIdentifier = (
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                )?.bundleIdentifier
                Task { @MainActor in
                    self?.send(.workspaceFocusChanged(
                        reason: "workspace-app-activated",
                        kind: .activated,
                        bundleIdentifier: bundleIdentifier
                    ))
                }
            },
            workspaceCenter.addObserver(
                forName: NSWorkspace.didDeactivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let bundleIdentifier = (
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                )?.bundleIdentifier
                Task { @MainActor in
                    self?.send(.workspaceFocusChanged(
                        reason: "workspace-app-deactivated",
                        kind: .deactivated,
                        bundleIdentifier: bundleIdentifier
                    ))
                }
            },
            addWorkspaceInterruptionObserver(
                workspaceCenter,
                name: NSWorkspace.willSleepNotification,
                kind: .systemWillSleep
            ),
            addWorkspaceInterruptionObserver(
                workspaceCenter,
                name: NSWorkspace.didWakeNotification,
                kind: .systemDidWake
            ),
            addWorkspaceInterruptionObserver(
                workspaceCenter,
                name: NSWorkspace.screensDidSleepNotification,
                kind: .displaysDidSleep
            ),
            addWorkspaceInterruptionObserver(
                workspaceCenter,
                name: NSWorkspace.screensDidWakeNotification,
                kind: .displaysDidWake
            )
        ]

        screenGeometryObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.send(.screenGeometryChanged)
            }
        }
    }

    func stop() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { workspaceCenter.removeObserver($0) }
        workspaceObservers.removeAll()
        if let screenGeometryObserver {
            NotificationCenter.default.removeObserver(screenGeometryObserver)
            self.screenGeometryObserver = nil
        }
    }

    private func addWorkspaceInterruptionObserver(
        _ center: NotificationCenter,
        name: NSNotification.Name,
        kind: SuggestionInterruptionKind
    ) -> NSObjectProtocol {
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.send(.suggestionInterruption(kind))
            }
        }
    }

    private func send(_ event: WorkspaceObserverEvent) {
        handler?.handleWorkspaceObserverEvent(event)
    }
}
