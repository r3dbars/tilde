import Foundation
import AutocompleteLabCore

protocol FocusedTextContextReading: AnyObject, Sendable {
    func focusedTextContext(
        for app: RunningApplicationInfo,
        allowDescendantTextFallback: Bool,
        options: FocusedTextReadOptions
    ) -> FocusedTextContext?
}

extension AccessibilityClient: FocusedTextContextReading {}

struct FocusedTextAXReadResult: Equatable, Sendable {
    let requestID: UInt64
    let app: RunningApplicationInfo
    let allowDescendantTextFallback: Bool
    let options: FocusedTextReadOptions
    let context: FocusedTextContext?
    let queueDelayMilliseconds: Int
    let readDurationMilliseconds: Int
}

enum FocusedTextReadOptionsPolicy {
    static func options(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> FocusedTextReadOptions {
        if app.bundleIdentifier == "com.openai.codex",
           profile.bundleIdentifier == "com.openai.codex" {
            return .syntheticTextAreaFastPath
        }

        return .standard
    }
}

final class SerialFocusedTextAXReader: @unchecked Sendable {
    typealias Read = @Sendable (
        _ app: RunningApplicationInfo,
        _ allowDescendantTextFallback: Bool,
        _ options: FocusedTextReadOptions
    ) -> FocusedTextContext?
    typealias Completion = @Sendable (FocusedTextAXReadResult) -> Void

    private let workQueue: DispatchQueue
    private let callbackQueue: DispatchQueue
    private let read: Read
    private let state = SerialFocusedTextAXReaderState()

    /// AppDelegate integration point: keep the fast frontmost-app/profile gates on the main actor,
    /// then enqueue the AX focused-text read here and process the latest matching request on return.
    init(
        label: String = "com.transcripted.autocomplete.focused-text-ax-reader",
        qos: DispatchQoS = .userInteractive,
        callbackQueue: DispatchQueue = .main,
        read: @escaping Read
    ) {
        self.workQueue = DispatchQueue(label: label, qos: qos)
        self.callbackQueue = callbackQueue
        self.read = read
    }

    convenience init(
        accessibilityClient: FocusedTextContextReading,
        callbackQueue: DispatchQueue = .main
    ) {
        self.init(callbackQueue: callbackQueue) { app, allowDescendantTextFallback, options in
            accessibilityClient.focusedTextContext(
                for: app,
                allowDescendantTextFallback: allowDescendantTextFallback,
                options: options
            )
        }
    }

    @discardableResult
    func readFocusedTextContext(
        for app: RunningApplicationInfo,
        allowDescendantTextFallback: Bool,
        options: FocusedTextReadOptions = .standard,
        completion: @escaping Completion
    ) -> UInt64 {
        let requestID = state.nextRequestID()
        let enqueuedAt = DispatchTime.now().uptimeNanoseconds

        workQueue.async { [callbackQueue, read] in
            let startedAt = DispatchTime.now().uptimeNanoseconds
            let context = read(app, allowDescendantTextFallback, options)
            let finishedAt = DispatchTime.now().uptimeNanoseconds
            let result = FocusedTextAXReadResult(
                requestID: requestID,
                app: app,
                allowDescendantTextFallback: allowDescendantTextFallback,
                options: options,
                context: context,
                queueDelayMilliseconds: Self.milliseconds(from: enqueuedAt, to: startedAt),
                readDurationMilliseconds: Self.milliseconds(from: startedAt, to: finishedAt)
            )

            callbackQueue.async {
                completion(result)
            }
        }

        return requestID
    }

    private static func milliseconds(from start: UInt64, to end: UInt64) -> Int {
        Int((end - start) / 1_000_000)
    }
}

private final class SerialFocusedTextAXReaderState: @unchecked Sendable {
    private let lock = NSLock()
    private var requestID: UInt64 = 0

    func nextRequestID() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

        requestID += 1
        return requestID
    }
}
