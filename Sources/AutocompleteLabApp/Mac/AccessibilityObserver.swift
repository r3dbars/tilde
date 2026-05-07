import ApplicationServices
import Foundation

enum FocusedTextUpdateSource: String, Equatable, Sendable {
    case observer
    case activePoll
    case watchPoll
    case idlePoll
    case manualRefresh

    var bypassesTypingPause: Bool {
        switch self {
        case .observer, .manualRefresh:
            true
        case .activePoll, .watchPoll, .idlePoll:
            false
        }
    }
}

struct FocusedTextUpdateSourcePolicy: Equatable, Sendable {
    func pollingSource(
        isTrustedForAccessibility: Bool,
        hasSupportedProfile: Bool,
        usesObserverUpdates: Bool,
        hasVisibleSuggestion: Bool
    ) -> FocusedTextUpdateSource {
        guard isTrustedForAccessibility else {
            return .idlePoll
        }

        if hasVisibleSuggestion {
            return .activePoll
        }

        if hasSupportedProfile && !usesObserverUpdates {
            return .watchPoll
        }

        return .idlePoll
    }

    func coalesced(
        _ current: FocusedTextUpdateSource?,
        with next: FocusedTextUpdateSource
    ) -> FocusedTextUpdateSource {
        guard let current else {
            return next
        }

        return priority(next) > priority(current) ? next : current
    }

    private func priority(_ source: FocusedTextUpdateSource) -> Int {
        switch source {
        case .observer:
            5
        case .manualRefresh:
            4
        case .activePoll:
            3
        case .watchPoll:
            2
        case .idlePoll:
            1
        }
    }
}

enum AccessibilityObserverEventKind: String, Equatable, Sendable {
    case focusedUIElementChanged
    case selectedTextChanged
    case valueChanged
    case focusedWindowChanged
    case windowMoved
    case windowResized

    init?(notificationName: String) {
        switch notificationName {
        case kAXFocusedUIElementChangedNotification:
            self = .focusedUIElementChanged
        case kAXSelectedTextChangedNotification:
            self = .selectedTextChanged
        case kAXValueChangedNotification:
            self = .valueChanged
        case kAXFocusedWindowChangedNotification:
            self = .focusedWindowChanged
        case kAXWindowMovedNotification:
            self = .windowMoved
        case kAXWindowResizedNotification:
            self = .windowResized
        default:
            return nil
        }
    }
}

enum AccessibilityObserverRouteAction: String, Equatable, Sendable {
    case reclassifyFocusedContext
    case refreshFocusedGeometry
}

struct AccessibilityObserverEventRouter: Equatable, Sendable {
    func route(_ kind: AccessibilityObserverEventKind) -> AccessibilityObserverRouteAction {
        switch kind {
        case .focusedUIElementChanged, .focusedWindowChanged:
            .reclassifyFocusedContext
        case .selectedTextChanged, .valueChanged, .windowMoved, .windowResized:
            .refreshFocusedGeometry
        }
    }
}

struct AccessibilityObserverEvent: Equatable, Sendable {
    let processIdentifier: pid_t
    let bundleIdentifier: String
    let localizedAppName: String
    let notificationName: String
    let kind: AccessibilityObserverEventKind
    let elementIdentifier: Int

    var metadata: [String: String] {
        [
            "app": bundleIdentifier,
            "appName": localizedAppName,
            "pid": String(processIdentifier),
            "notification": notificationName,
            "kind": kind.rawValue,
            "elementID": String(elementIdentifier),
            "updateSource": FocusedTextUpdateSource.observer.rawValue
        ]
    }
}

struct AccessibilityObserverRegistrationFailure: Equatable, Sendable {
    let processIdentifier: pid_t
    let bundleIdentifier: String
    let localizedAppName: String
    let notificationName: String
    let target: String
    let errorName: String
    let errorCode: Int32

    var metadata: [String: String] {
        [
            "app": bundleIdentifier,
            "appName": localizedAppName,
            "pid": String(processIdentifier),
            "notification": notificationName,
            "target": target,
            "error": errorName,
            "errorCode": String(errorCode)
        ]
    }
}

@MainActor
final class AccessibilityObserver {
    typealias EventHandler = @Sendable (AccessibilityObserverEvent) -> Void
    typealias RegistrationFailureHandler = @Sendable (AccessibilityObserverRegistrationFailure) -> Void

    private let eventHandler: EventHandler
    private let registrationFailureHandler: RegistrationFailureHandler
    private var trackedObservers: [pid_t: TrackedAXObserver] = [:]
    private var observerPIDByIdentifier: [Int: pid_t] = [:]
    private var reportedRegistrationFailures: Set<String> = []

    init(
        eventHandler: @escaping EventHandler,
        registrationFailureHandler: @escaping RegistrationFailureHandler
    ) {
        self.eventHandler = eventHandler
        self.registrationFailureHandler = registrationFailureHandler
    }

    func isTracking(processIdentifier: pid_t) -> Bool {
        trackedObservers[processIdentifier]?.registrations.isEmpty == false
    }

    func observe(
        app: RunningApplicationInfo,
        focusedElement: AXUIElement?,
        focusedWindow: AXUIElement?
    ) {
        stopTrackingPIDs(except: app.processIdentifier)

        guard let trackedObserver = trackedObserver(for: app) else {
            return
        }

        let signature = AccessibilityObserverTargetSignature(
            focusedElementIdentifier: focusedElement.map { Int(CFHash($0)) },
            focusedWindowIdentifier: focusedWindow.map { Int(CFHash($0)) }
        )
        guard trackedObserver.signature != signature else {
            return
        }

        removeRegistrations(from: trackedObserver)

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        register(
            kAXFocusedUIElementChangedNotification,
            on: appElement,
            target: "application",
            app: app,
            trackedObserver: trackedObserver
        )
        register(
            kAXFocusedWindowChangedNotification,
            on: appElement,
            target: "application",
            app: app,
            trackedObserver: trackedObserver
        )

        if let focusedElement {
            register(
                kAXSelectedTextChangedNotification,
                on: focusedElement,
                target: "focusedElement",
                app: app,
                trackedObserver: trackedObserver
            )
            register(
                kAXValueChangedNotification,
                on: focusedElement,
                target: "focusedElement",
                app: app,
                trackedObserver: trackedObserver
            )
        }

        if let focusedWindow {
            register(
                kAXWindowMovedNotification,
                on: focusedWindow,
                target: "focusedWindow",
                app: app,
                trackedObserver: trackedObserver
            )
            register(
                kAXWindowResizedNotification,
                on: focusedWindow,
                target: "focusedWindow",
                app: app,
                trackedObserver: trackedObserver
            )
        }

        trackedObserver.signature = signature
    }

    func stopTrackingAll() {
        let observers = trackedObservers.values
        for trackedObserver in observers {
            removeRegistrations(from: trackedObserver)
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(trackedObserver.observer),
                .commonModes
            )
        }
        trackedObservers.removeAll()
        observerPIDByIdentifier.removeAll()
    }

    private func trackedObserver(for app: RunningApplicationInfo) -> TrackedAXObserver? {
        if let observer = trackedObservers[app.processIdentifier] {
            return observer
        }

        var observer: AXObserver?
        let error = AXObserverCreate(app.processIdentifier, accessibilityObserverAXCallback, &observer)
        guard error == .success, let observer else {
            recordRegistrationFailure(
                app: app,
                notificationName: "AXObserverCreate",
                target: "application",
                error: error
            )
            return nil
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )

        let trackedObserver = TrackedAXObserver(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            localizedAppName: app.localizedName,
            observer: observer,
            observerIdentifier: Int(CFHash(observer))
        )
        trackedObservers[app.processIdentifier] = trackedObserver
        observerPIDByIdentifier[trackedObserver.observerIdentifier] = app.processIdentifier
        return trackedObserver
    }

    private func register(
        _ notificationName: String,
        on element: AXUIElement,
        target: String,
        app: RunningApplicationInfo,
        trackedObserver: TrackedAXObserver
    ) {
        let error = AXObserverAddNotification(
            trackedObserver.observer,
            element,
            notificationName as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )

        guard error == .success else {
            recordRegistrationFailure(
                app: app,
                notificationName: notificationName,
                target: target,
                error: error
            )
            return
        }

        trackedObserver.registrations.append(AccessibilityObserverRegistration(
            element: element,
            notificationName: notificationName
        ))
    }

    private func removeRegistrations(from trackedObserver: TrackedAXObserver) {
        for registration in trackedObserver.registrations {
            AXObserverRemoveNotification(
                trackedObserver.observer,
                registration.element,
                registration.notificationName as CFString
            )
        }
        trackedObserver.registrations.removeAll()
    }

    private func stopTrackingPIDs(except processIdentifier: pid_t) {
        let stalePIDs = trackedObservers.keys.filter { $0 != processIdentifier }
        for pid in stalePIDs {
            guard let trackedObserver = trackedObservers.removeValue(forKey: pid) else {
                continue
            }

            removeRegistrations(from: trackedObserver)
            observerPIDByIdentifier[trackedObserver.observerIdentifier] = nil
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(trackedObserver.observer),
                .commonModes
            )
        }
    }

    private func recordRegistrationFailure(
        app: RunningApplicationInfo,
        notificationName: String,
        target: String,
        error: AXError
    ) {
        let failure = AccessibilityObserverRegistrationFailure(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            localizedAppName: app.localizedName,
            notificationName: notificationName,
            target: target,
            errorName: String(describing: error),
            errorCode: error.rawValue
        )
        let signature = [
            failure.bundleIdentifier,
            String(failure.processIdentifier),
            failure.notificationName,
            failure.target,
            failure.errorName
        ].joined(separator: "|")

        guard !reportedRegistrationFailures.contains(signature) else {
            return
        }
        reportedRegistrationFailures.insert(signature)
        registrationFailureHandler(failure)
    }

    fileprivate func handleAXNotification(
        observerIdentifier: Int,
        notificationName: String,
        elementIdentifier: Int
    ) {
        guard let processIdentifier = observerPIDByIdentifier[observerIdentifier],
              let trackedObserver = trackedObservers[processIdentifier],
              let kind = AccessibilityObserverEventKind(notificationName: notificationName) else {
            return
        }

        eventHandler(AccessibilityObserverEvent(
            processIdentifier: trackedObserver.processIdentifier,
            bundleIdentifier: trackedObserver.bundleIdentifier,
            localizedAppName: trackedObserver.localizedAppName,
            notificationName: notificationName,
            kind: kind,
            elementIdentifier: elementIdentifier
        ))
    }
}

private final class TrackedAXObserver {
    let processIdentifier: pid_t
    let bundleIdentifier: String
    let localizedAppName: String
    let observer: AXObserver
    let observerIdentifier: Int
    var signature: AccessibilityObserverTargetSignature?
    var registrations: [AccessibilityObserverRegistration] = []

    init(
        processIdentifier: pid_t,
        bundleIdentifier: String,
        localizedAppName: String,
        observer: AXObserver,
        observerIdentifier: Int
    ) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.localizedAppName = localizedAppName
        self.observer = observer
        self.observerIdentifier = observerIdentifier
    }
}

private struct AccessibilityObserverTargetSignature: Equatable {
    let focusedElementIdentifier: Int?
    let focusedWindowIdentifier: Int?
}

private struct AccessibilityObserverRegistration {
    let element: AXUIElement
    let notificationName: String
}

private let accessibilityObserverAXCallback: AXObserverCallback = { observer, element, notification, refcon in
    guard let refcon else {
        return
    }

    let instance = Unmanaged<AccessibilityObserver>.fromOpaque(refcon).takeUnretainedValue()
    let observerIdentifier = Int(CFHash(observer))
    let elementIdentifier = Int(CFHash(element))
    let notificationName = notification as String

    Task { @MainActor in
        instance.handleAXNotification(
            observerIdentifier: observerIdentifier,
            notificationName: notificationName,
            elementIdentifier: elementIdentifier
        )
    }
}
