import AppKit
import ApplicationServices

enum AXFocusedTextNotificationKind: String, Hashable, Sendable {
    case focusedUIElementChanged
    case valueChanged
    case selectedTextChanged
}

struct AXFocusedTextEventBurst: Equatable, Sendable {
    let processIdentifier: pid_t
    let notifications: Set<AXFocusedTextNotificationKind>
}

final class AXFocusedTextEventCoalescer: @unchecked Sendable {
    typealias Delivery = @Sendable (AXFocusedTextEventBurst) -> Void

    private let interval: TimeInterval
    private let queue: DispatchQueue
    private let queueIdentityKey = DispatchSpecificKey<UInt8>()
    private let delivery: Delivery
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var pendingProcessIdentifier: pid_t?
    private var pendingNotifications: Set<AXFocusedTextNotificationKind> = []

    init(
        interval: TimeInterval = 0.015,
        queue: DispatchQueue = DispatchQueue(
            label: "com.transcripted.autocomplete.focused-text-ax-events",
            qos: .userInteractive
        ),
        delivery: @escaping Delivery
    ) {
        self.interval = max(0.01, min(interval, 0.02))
        self.queue = queue
        self.delivery = delivery
        self.queue.setSpecific(key: queueIdentityKey, value: 1)
    }

    func submit(processIdentifier: pid_t, notification: AXFocusedTextNotificationKind) {
        let scheduledGeneration = withLock { () -> UInt64 in
            generation += 1
            if pendingProcessIdentifier != processIdentifier {
                pendingNotifications.removeAll(keepingCapacity: true)
            }
            pendingProcessIdentifier = processIdentifier
            pendingNotifications.insert(notification)
            return generation
        }

        queue.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.flush(generation: scheduledGeneration)
        }
    }

    func cancelPending() {
        withLock {
            generation += 1
            pendingProcessIdentifier = nil
            pendingNotifications.removeAll(keepingCapacity: true)
        }

        // A flush may already have extracted its burst before cancellation took the lock.
        // Drain that handoff so no pre-cancellation delivery can fire after this returns.
        if DispatchQueue.getSpecific(key: queueIdentityKey) == nil {
            queue.sync(flags: .barrier) {}
        }
    }

    private func flush(generation scheduledGeneration: UInt64) {
        let burst = withLock { () -> AXFocusedTextEventBurst? in
            guard generation == scheduledGeneration,
                  let processIdentifier = pendingProcessIdentifier,
                  !pendingNotifications.isEmpty else {
                return nil
            }

            let burst = AXFocusedTextEventBurst(
                processIdentifier: processIdentifier,
                notifications: pendingNotifications
            )
            pendingProcessIdentifier = nil
            pendingNotifications.removeAll(keepingCapacity: true)
            return burst
        }

        if let burst {
            delivery(burst)
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

struct AXFocusedTextObserverLifecycle: Equatable, Sendable {
    private(set) var isStarted = false
    private(set) var generation: UInt64 = 0

    mutating func start() -> UInt64 {
        if !isStarted {
            generation &+= 1
            isStarted = true
        }
        return generation
    }

    mutating func stop() {
        generation &+= 1
        isStarted = false
    }

    func accepts(generation candidate: UInt64) -> Bool {
        isStarted && generation == candidate
    }
}

/// Owns the native AX notification lifecycle for the frontmost application.
///
/// The delivered burst contains only notification kinds and a process identifier. It never
/// reads, stores, or logs focused text. Integration should enqueue one focused-text read on the
/// existing `SerialFocusedTextAXReader` for each delivered burst.
@MainActor
final class AXFocusedTextEventObserver {
    typealias Delivery = AXFocusedTextEventCoalescer.Delivery

    private let workspace: NSWorkspace
    private let coalescer: AXFocusedTextEventCoalescer
    private var workspaceNotificationTokens: [NSObjectProtocol] = []
    private var observer: AXObserver?
    private var applicationElement: AXUIElement?
    private var focusedElement: AXUIElement?
    private var lifecycle = AXFocusedTextObserverLifecycle()
    private(set) var observedProcessIdentifier: pid_t?

    init(
        workspace: NSWorkspace = .shared,
        coalescingInterval: TimeInterval = 0.015,
        eventQueue: DispatchQueue = DispatchQueue(
            label: "com.transcripted.autocomplete.focused-text-ax-events",
            qos: .userInteractive
        ),
        delivery: @escaping Delivery
    ) {
        self.workspace = workspace
        self.coalescer = AXFocusedTextEventCoalescer(
            interval: coalescingInterval,
            queue: eventQueue,
            delivery: delivery
        )
    }

    isolated deinit {
        stop()
    }

    func start() {
        guard workspaceNotificationTokens.isEmpty else {
            return
        }

        let registrationGeneration = lifecycle.start()
        let center = workspace.notificationCenter
        workspaceNotificationTokens = [
            center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let processIdentifier = (
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                        as? NSRunningApplication
                )?.processIdentifier
                MainActor.assumeIsolated {
                    if let processIdentifier {
                        self?.handleActivation(
                            processIdentifier: processIdentifier,
                            generation: registrationGeneration
                        )
                    }
                }
            },
            center.addObserver(
                forName: NSWorkspace.didDeactivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let processIdentifier = (
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                        as? NSRunningApplication
                )?.processIdentifier
                MainActor.assumeIsolated {
                    self?.handleDeactivation(
                        processIdentifier: processIdentifier,
                        generation: registrationGeneration
                    )
                }
            },
            center.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let processIdentifier = (
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                        as? NSRunningApplication
                )?.processIdentifier
                MainActor.assumeIsolated {
                    self?.handleDeactivation(
                        processIdentifier: processIdentifier,
                        generation: registrationGeneration
                    )
                }
            }
        ]

        if let processIdentifier = workspace.frontmostApplication?.processIdentifier {
            handleActivation(
                processIdentifier: processIdentifier,
                generation: registrationGeneration
            )
        }
    }

    func stop() {
        lifecycle.stop()
        let center = workspace.notificationCenter
        workspaceNotificationTokens.forEach(center.removeObserver)
        workspaceNotificationTokens.removeAll()
        tearDownObserver()
    }

    private func handleActivation(processIdentifier: pid_t, generation: UInt64) {
        guard lifecycle.accepts(generation: generation) else {
            return
        }

        observe(processIdentifier: processIdentifier)
    }

    private func handleDeactivation(processIdentifier: pid_t?, generation: UInt64) {
        guard lifecycle.accepts(generation: generation),
              observedProcessIdentifier == processIdentifier else {
            return
        }

        tearDownObserver()
    }

    private func observe(processIdentifier: pid_t) {
        guard lifecycle.isStarted else {
            return
        }

        guard observedProcessIdentifier != processIdentifier else {
            return
        }

        tearDownObserver()

        var createdObserver: AXObserver?
        guard AXObserverCreate(
            processIdentifier,
            Self.observerCallback,
            &createdObserver
        ) == .success, let createdObserver else {
            return
        }

        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard Self.addNotification(
            kAXFocusedUIElementChangedNotification,
            observer: createdObserver,
            element: applicationElement,
            context: context
        ) else {
            return
        }

        self.observer = createdObserver
        self.applicationElement = applicationElement
        observedProcessIdentifier = processIdentifier
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(createdObserver),
            .defaultMode
        )
        registerFocusedElementNotifications()
    }

    private func registerFocusedElementNotifications() {
        guard let observer, let applicationElement else {
            return
        }

        removeFocusedElementNotifications()

        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return
        }

        let focusedElement = focusedValue as! AXUIElement
        let context = Unmanaged.passUnretained(self).toOpaque()
        let observesValue = Self.addNotification(
            kAXValueChangedNotification,
            observer: observer,
            element: focusedElement,
            context: context
        )
        let observesSelection = Self.addNotification(
            kAXSelectedTextChangedNotification,
            observer: observer,
            element: focusedElement,
            context: context
        )

        if observesValue || observesSelection {
            self.focusedElement = focusedElement
        }
    }

    private func removeFocusedElementNotifications() {
        guard let observer, let focusedElement else {
            return
        }

        AXObserverRemoveNotification(
            observer,
            focusedElement,
            kAXValueChangedNotification as CFString
        )
        AXObserverRemoveNotification(
            observer,
            focusedElement,
            kAXSelectedTextChangedNotification as CFString
        )
        self.focusedElement = nil
    }

    private func tearDownObserver() {
        coalescer.cancelPending()
        removeFocusedElementNotifications()

        if let observer, let applicationElement {
            AXObserverRemoveNotification(
                observer,
                applicationElement,
                kAXFocusedUIElementChangedNotification as CFString
            )
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }

        observer = nil
        applicationElement = nil
        observedProcessIdentifier = nil
    }

    private func handle(notification: AXFocusedTextNotificationKind) {
        guard lifecycle.isStarted,
              let processIdentifier = observedProcessIdentifier else {
            return
        }

        if notification == .focusedUIElementChanged {
            registerFocusedElementNotifications()
        }
        coalescer.submit(processIdentifier: processIdentifier, notification: notification)
    }

    private static func addNotification(
        _ notification: String,
        observer: AXObserver,
        element: AXUIElement,
        context: UnsafeMutableRawPointer
    ) -> Bool {
        let result = AXObserverAddNotification(
            observer,
            element,
            notification as CFString,
            context
        )
        return result == .success || result == .notificationAlreadyRegistered
    }

    private nonisolated static let observerCallback: AXObserverCallback = {
        _, _, notification, context in
        guard let context,
              let notification = notificationKind(for: notification as String) else {
            return
        }

        let owner = Unmanaged<AXFocusedTextEventObserver>
            .fromOpaque(context)
            .takeUnretainedValue()
        MainActor.assumeIsolated {
            owner.handle(notification: notification)
        }
    }

    private nonisolated static func notificationKind(
        for notification: String
    ) -> AXFocusedTextNotificationKind? {
        switch notification {
        case kAXFocusedUIElementChangedNotification:
            .focusedUIElementChanged
        case kAXValueChangedNotification:
            .valueChanged
        case kAXSelectedTextChangedNotification:
            .selectedTextChanged
        default:
            nil
        }
    }
}
