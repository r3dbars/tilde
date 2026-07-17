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

struct AXFocusedTextObservationTarget: Equatable, Sendable {
    private(set) var processIdentifier: pid_t?
    private(set) var generation: UInt64 = 0

    mutating func begin(processIdentifier: pid_t) -> UInt64 {
        generation &+= 1
        self.processIdentifier = processIdentifier
        return generation
    }

    mutating func cancel() {
        generation &+= 1
        processIdentifier = nil
    }

    func accepts(processIdentifier: pid_t, generation candidate: UInt64) -> Bool {
        self.processIdentifier == processIdentifier && generation == candidate
    }
}

struct AXFocusedTextSetupRetry: Equatable, Sendable {
    let attempt: Int
    let delayMilliseconds: Int
}

struct AXFocusedTextSetupRetryPolicy: Equatable, Sendable {
    let maximumRetryAttempts: Int
    let delayMilliseconds: Int

    init(maximumRetryAttempts: Int = 3, delayMilliseconds: Int = 50) {
        self.maximumRetryAttempts = max(0, maximumRetryAttempts)
        self.delayMilliseconds = max(1, delayMilliseconds)
    }

    func next(after error: AXError, failedAttempt: Int) -> AXFocusedTextSetupRetry? {
        guard canRetry(error),
              failedAttempt >= 0,
              failedAttempt < maximumRetryAttempts else {
            return nil
        }

        return AXFocusedTextSetupRetry(
            attempt: failedAttempt + 1,
            delayMilliseconds: delayMilliseconds
        )
    }

    func canRetry(_ error: AXError) -> Bool {
        Self.isTransient(error)
    }

    private static func isTransient(_ error: AXError) -> Bool {
        error == .cannotComplete || error == .noValue
    }
}

struct AXFocusedTextMessagingTimeoutConfigurator {
    typealias Setter = (AXUIElement, Float) -> AXError

    static let defaultTimeoutSeconds: Float = 0.12

    let timeoutSeconds: Float
    private let setter: Setter

    init(
        timeoutSeconds: Float = Self.defaultTimeoutSeconds,
        setter: @escaping Setter = { element, timeout in
            AXUIElementSetMessagingTimeout(element, timeout)
        }
    ) {
        self.timeoutSeconds = max(0.01, timeoutSeconds)
        self.setter = setter
    }

    @discardableResult
    func configure(_ element: AXUIElement) -> AXError {
        setter(element, timeoutSeconds)
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
    private let messagingTimeoutConfigurator: AXFocusedTextMessagingTimeoutConfigurator
    private let setupRetryPolicy: AXFocusedTextSetupRetryPolicy
    private var workspaceNotificationTokens: [NSObjectProtocol] = []
    private var observer: AXObserver?
    private var applicationElement: AXUIElement?
    private var focusedElement: AXUIElement?
    private var setupRetryTask: Task<Void, Never>?
    private var lifecycle = AXFocusedTextObserverLifecycle()
    private var observationTarget = AXFocusedTextObservationTarget()
    private(set) var observedProcessIdentifier: pid_t?

    init(
        workspace: NSWorkspace = .shared,
        coalescingInterval: TimeInterval = 0.015,
        eventQueue: DispatchQueue = DispatchQueue(
            label: "com.transcripted.autocomplete.focused-text-ax-events",
            qos: .userInteractive
        ),
        messagingTimeoutConfigurator: AXFocusedTextMessagingTimeoutConfigurator = .init(),
        setupRetryPolicy: AXFocusedTextSetupRetryPolicy = .init(),
        delivery: @escaping Delivery
    ) {
        self.workspace = workspace
        self.messagingTimeoutConfigurator = messagingTimeoutConfigurator
        self.setupRetryPolicy = setupRetryPolicy
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
              observationTarget.processIdentifier == processIdentifier else {
            return
        }

        tearDownObserver()
    }

    private func observe(processIdentifier: pid_t) {
        guard lifecycle.isStarted else {
            return
        }

        guard observationTarget.processIdentifier != processIdentifier else {
            return
        }

        tearDownObserver()

        let observationGeneration = observationTarget.begin(
            processIdentifier: processIdentifier
        )
        attemptObservation(
            processIdentifier: processIdentifier,
            generation: observationGeneration,
            attempt: 0
        )
    }

    private func attemptObservation(
        processIdentifier: pid_t,
        generation: UInt64,
        attempt: Int
    ) {
        guard lifecycle.isStarted,
              observationTarget.accepts(
                processIdentifier: processIdentifier,
                generation: generation
              ) else {
            return
        }

        var createdObserver: AXObserver?
        let createResult = AXObserverCreate(
            processIdentifier,
            Self.observerCallback,
            &createdObserver
        )
        guard createResult == .success, let createdObserver else {
            scheduleSetupRetry(
                after: createResult,
                processIdentifier: processIdentifier,
                generation: generation,
                failedAttempt: attempt
            )
            return
        }

        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        messagingTimeoutConfigurator.configure(applicationElement)
        let context = Unmanaged.passUnretained(self).toOpaque()
        let registrationResult = Self.addNotification(
            kAXFocusedUIElementChangedNotification,
            observer: createdObserver,
            element: applicationElement,
            context: context
        )
        guard Self.acceptsNotificationRegistration(registrationResult) else {
            scheduleSetupRetry(
                after: registrationResult,
                processIdentifier: processIdentifier,
                generation: generation,
                failedAttempt: attempt
            )
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
        registerFocusedElementNotifications(
            processIdentifier: processIdentifier,
            generation: generation,
            attempt: attempt
        )
    }

    private func registerFocusedElementNotifications(
        processIdentifier: pid_t,
        generation: UInt64,
        attempt: Int
    ) {
        guard observationTarget.accepts(
            processIdentifier: processIdentifier,
            generation: generation
        ), let observer, let applicationElement else {
            return
        }

        cancelSetupRetry()
        removeFocusedElementNotifications()

        var focusedValue: CFTypeRef?
        let focusedElementResult = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusedElementResult == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            scheduleSetupRetry(
                after: focusedElementResult == .success ? .noValue : focusedElementResult,
                processIdentifier: processIdentifier,
                generation: generation,
                failedAttempt: attempt
            )
            return
        }

        let focusedElement = focusedValue as! AXUIElement
        messagingTimeoutConfigurator.configure(focusedElement)
        let context = Unmanaged.passUnretained(self).toOpaque()
        let valueRegistrationResult = Self.addNotification(
            kAXValueChangedNotification,
            observer: observer,
            element: focusedElement,
            context: context
        )
        let selectionRegistrationResult = Self.addNotification(
            kAXSelectedTextChangedNotification,
            observer: observer,
            element: focusedElement,
            context: context
        )

        let observesValue = Self.acceptsNotificationRegistration(valueRegistrationResult)
        let observesSelection = Self.acceptsNotificationRegistration(selectionRegistrationResult)
        if observesValue || observesSelection {
            self.focusedElement = focusedElement
        } else if let transientResult = [valueRegistrationResult, selectionRegistrationResult]
            .first(where: setupRetryPolicy.canRetry) {
            scheduleSetupRetry(
                after: transientResult,
                processIdentifier: processIdentifier,
                generation: generation,
                failedAttempt: attempt
            )
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
        observationTarget.cancel()
        cancelSetupRetry()
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
            guard let processIdentifier = observationTarget.processIdentifier else {
                return
            }
            registerFocusedElementNotifications(
                processIdentifier: processIdentifier,
                generation: observationTarget.generation,
                attempt: 0
            )
        }
        coalescer.submit(processIdentifier: processIdentifier, notification: notification)
    }

    private func scheduleSetupRetry(
        after error: AXError,
        processIdentifier: pid_t,
        generation: UInt64,
        failedAttempt: Int
    ) {
        guard lifecycle.isStarted,
              observationTarget.accepts(
                processIdentifier: processIdentifier,
                generation: generation
              ),
              let retry = setupRetryPolicy.next(
                after: error,
                failedAttempt: failedAttempt
              ) else {
            return
        }

        cancelSetupRetry()
        setupRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(retry.delayMilliseconds))
            guard !Task.isCancelled, let self else {
                return
            }

            self.setupRetryTask = nil
            guard self.lifecycle.isStarted,
                  self.observationTarget.accepts(
                    processIdentifier: processIdentifier,
                    generation: generation
                  ) else {
                return
            }

            if self.observer == nil {
                self.attemptObservation(
                    processIdentifier: processIdentifier,
                    generation: generation,
                    attempt: retry.attempt
                )
            } else {
                self.registerFocusedElementNotifications(
                    processIdentifier: processIdentifier,
                    generation: generation,
                    attempt: retry.attempt
                )
            }
        }
    }

    private func cancelSetupRetry() {
        setupRetryTask?.cancel()
        setupRetryTask = nil
    }

    private static func addNotification(
        _ notification: String,
        observer: AXObserver,
        element: AXUIElement,
        context: UnsafeMutableRawPointer
    ) -> AXError {
        AXObserverAddNotification(
            observer,
            element,
            notification as CFString,
            context
        )
    }

    private static func acceptsNotificationRegistration(_ result: AXError) -> Bool {
        result == .success || result == .notificationAlreadyRegistered
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
