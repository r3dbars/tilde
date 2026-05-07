import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Serial focused text AX reader")
struct SerialFocusedTextAXReaderTests {
    @Test("Returns while focused text read is still running")
    func returnsWhileFocusedTextReadIsStillRunning() {
        let readStarted = DispatchSemaphore(value: 0)
        let allowReadToFinish = DispatchSemaphore(value: 0)
        let completionReceived = DispatchSemaphore(value: 0)
        let callbackQueue = DispatchQueue(label: "SerialFocusedTextAXReaderTests.callback.async")
        let reader = SerialFocusedTextAXReader(
            label: "SerialFocusedTextAXReaderTests.work.async",
            callbackQueue: callbackQueue
        ) { app, _ in
            #expect(app.bundleIdentifier == "com.example.Editor")
            readStarted.signal()
            allowReadToFinish.wait()
            return focusedTextContext(textBeforeCursor: "hel")
        }

        let startedAt = DispatchTime.now().uptimeNanoseconds
        let requestID = reader.readFocusedTextContext(
            for: runningApplicationInfo(),
            allowDescendantTextFallback: true
        ) { result in
            #expect(result.requestID == 1)
            #expect(result.app == runningApplicationInfo())
            #expect(result.allowDescendantTextFallback)
            #expect(result.context?.textBeforeCursor == "hel")
            completionReceived.signal()
        }
        let returnedAt = DispatchTime.now().uptimeNanoseconds

        #expect(requestID == 1)
        #expect(Int((returnedAt - startedAt) / 1_000_000) < 50)
        #expect(readStarted.wait(timeout: .now() + 1) == .success)
        allowReadToFinish.signal()
        #expect(completionReceived.wait(timeout: .now() + 1) == .success)
    }

    @Test("Runs focused text reads one at a time in request order")
    func runsFocusedTextReadsOneAtATimeInRequestOrder() {
        let recorder = SerialReadRecorder()
        let completionGroup = DispatchGroup()
        let callbackQueue = DispatchQueue(label: "SerialFocusedTextAXReaderTests.callback.serial")
        let reader = SerialFocusedTextAXReader(
            label: "SerialFocusedTextAXReaderTests.work.serial",
            callbackQueue: callbackQueue
        ) { _, _ in
            recorder.recordRead {
                Thread.sleep(forTimeInterval: 0.02)
                return focusedTextContext(textBeforeCursor: "read-\($0)")
            }
        }

        for _ in 0..<4 {
            completionGroup.enter()
            _ = reader.readFocusedTextContext(
                for: runningApplicationInfo(),
                allowDescendantTextFallback: false
            ) { result in
                    recorder.recordCompletion(requestID: result.requestID, context: result.context)
                    completionGroup.leave()
                }
        }

        #expect(completionGroup.wait(timeout: .now() + 2) == .success)
        #expect(recorder.maxConcurrentReads == 1)
        #expect(recorder.readOrder == [1, 2, 3, 4])
        #expect(recorder.completionOrder == [1, 2, 3, 4])
        #expect(recorder.completedText == ["read-1", "read-2", "read-3", "read-4"])
    }
}

private final class SerialReadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var activeReads = 0
    private var nextReadNumber = 0
    private var _maxConcurrentReads = 0
    private var _readOrder: [Int] = []
    private var _completionOrder: [UInt64] = []
    private var _completedText: [String] = []

    var maxConcurrentReads: Int {
        withLock { _maxConcurrentReads }
    }

    var readOrder: [Int] {
        withLock { _readOrder }
    }

    var completionOrder: [UInt64] {
        withLock { _completionOrder }
    }

    var completedText: [String] {
        withLock { _completedText }
    }

    func recordRead(_ body: (Int) -> FocusedTextContext?) -> FocusedTextContext? {
        let readNumber = beginRead()
        let context = body(readNumber)
        endRead()
        return context
    }

    func recordCompletion(requestID: UInt64, context: FocusedTextContext?) {
        withLock {
            _completionOrder.append(requestID)
            _completedText.append(context?.textBeforeCursor ?? "")
        }
    }

    private func beginRead() -> Int {
        withLock {
            activeReads += 1
            nextReadNumber += 1
            _maxConcurrentReads = max(_maxConcurrentReads, activeReads)
            _readOrder.append(nextReadNumber)
            return nextReadNumber
        }
    }

    private func endRead() {
        withLock {
            activeReads -= 1
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private func runningApplicationInfo() -> RunningApplicationInfo {
    RunningApplicationInfo(
        bundleIdentifier: "com.example.Editor",
        localizedName: "Example Editor",
        processIdentifier: 42
    )
}

private func focusedTextContext(textBeforeCursor: String) -> FocusedTextContext {
    FocusedTextContext(
        elementIdentifier: 1,
        role: nil,
        subrole: nil,
        fingerprint: .init(),
        textBeforeCursor: textBeforeCursor,
        textAfterCursor: "",
        selectedTextLength: 0,
        caretRect: nil,
        elementRect: nil,
        windowRect: nil,
        textLineRect: nil,
        visibleCharacterRange: nil,
        insertionPointLineNumber: nil,
        textStyle: nil,
        isSecure: false,
        caretIsSynthetic: false,
        capabilities: FocusedTextCapabilities(
            canReadValue: true,
            canReadSelectedTextRange: true,
            canReadBoundsForRange: false,
            canReadAttributedText: false,
            canSetSelectedText: true
        ),
        axReadErrors: []
    )
}
