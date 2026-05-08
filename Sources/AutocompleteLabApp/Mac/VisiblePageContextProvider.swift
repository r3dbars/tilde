import AppKit
import AutocompleteLabCore
import CoreGraphics
import ImageIO
import Vision

final class VisiblePageContextProvider: @unchecked Sendable {
    static let shared = VisiblePageContextProvider()

    private struct CacheKey: Equatable {
        let bundleIdentifier: String
        let windowIdentifier: Int?
        let fieldIdentifier: Int
        let rectSignature: String
    }

    private struct CacheEntry {
        let key: CacheKey
        let context: VisiblePageContext
        let capturedAt: Date
    }

    private let queue = DispatchQueue(
        label: "app.transcripted.autocomplete.visible-page-context",
        qos: .utility
    )
    private let lock = NSLock()
    private let minimumRefreshInterval: TimeInterval = 1.5
    private let maximumCacheAge: TimeInterval = 8
    private let maximumCaptureSize = CGSize(width: 1_200, height: 900)
    private var cacheEntry: CacheEntry?
    private var inFlightKey: CacheKey?
    private var lastAttemptAt: Date?
    private var lastPermissionNoticeAt: Date?

    init() {}

    func cachedContext(
        for focusedContext: FocusedTextContext,
        appBundleIdentifier: String,
        now: Date = Date()
    ) -> VisiblePageContext? {
        let key = cacheKey(for: focusedContext, appBundleIdentifier: appBundleIdentifier)

        lock.lock()
        defer { lock.unlock() }

        guard let cacheEntry,
              cacheEntry.key == key,
              now.timeIntervalSince(cacheEntry.capturedAt) <= maximumCacheAge else {
            return nil
        }

        return cacheEntry.context
    }

    func refreshIfNeeded(
        for focusedContext: FocusedTextContext,
        app: RunningApplicationInfo,
        enabled: Bool,
        now: Date = Date()
    ) {
        guard enabled else {
            clear()
            return
        }
        guard !focusedContext.isSecure,
              focusedContext.selectedTextLength == 0,
              let captureRect = captureRect(for: focusedContext) else {
            return
        }

        guard CGPreflightScreenCaptureAccess() else {
            recordPermissionNoticeIfNeeded(appBundleIdentifier: app.bundleIdentifier, now: now)
            return
        }

        let key = cacheKey(for: focusedContext, appBundleIdentifier: app.bundleIdentifier)
        guard reserveRefreshIfNeeded(key: key, now: now) else {
            return
        }

        queue.async { [weak self] in
            self?.captureAndRecognize(
                rect: captureRect,
                key: key,
                appBundleIdentifier: app.bundleIdentifier,
                startedAt: now
            )
        }
    }

    func clear() {
        lock.lock()
        cacheEntry = nil
        inFlightKey = nil
        lock.unlock()
    }

    private func reserveRefreshIfNeeded(key: CacheKey, now: Date) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if inFlightKey == key {
            return false
        }

        if let cacheEntry,
           cacheEntry.key == key,
           now.timeIntervalSince(cacheEntry.capturedAt) < minimumRefreshInterval {
            return false
        }

        if let lastAttemptAt,
           now.timeIntervalSince(lastAttemptAt) < minimumRefreshInterval {
            return false
        }

        lastAttemptAt = now
        inFlightKey = key
        return true
    }

    private func captureAndRecognize(
        rect: CGRect,
        key: CacheKey,
        appBundleIdentifier: String,
        startedAt: Date
    ) {
        defer {
            lock.lock()
            if inFlightKey == key {
                inFlightKey = nil
            }
            lock.unlock()
        }

        guard let image = captureImage(
            rect: rect,
            appBundleIdentifier: appBundleIdentifier,
            startedAt: startedAt
        ) else {
            return
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.012

        do {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
        } catch {
            DiagnosticsLog.shared.record(
                "visible-page-context-ocr-failed",
                metadata: [
                    "app": appBundleIdentifier,
                    "reason": error.localizedDescription
                ]
            )
            return
        }

        let recognizedText = request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n") ?? ""

        guard let pageContext = VisiblePageContext(text: recognizedText) else {
            DiagnosticsLog.shared.record(
                "visible-page-context-empty",
                metadata: [
                    "app": appBundleIdentifier,
                    "durationMilliseconds": String(Self.milliseconds(from: startedAt, to: Date()))
                ]
            )
            return
        }

        lock.lock()
        cacheEntry = CacheEntry(key: key, context: pageContext, capturedAt: Date())
        lock.unlock()

        DiagnosticsLog.shared.record(
            "visible-page-context-ready",
            metadata: [
                "app": appBundleIdentifier,
                "chars": String(pageContext.text.count),
                "lines": pageContext.traceMetadata["visiblePageContextLines"] ?? "0",
                "durationMilliseconds": String(Self.milliseconds(from: startedAt, to: Date()))
            ]
        )
    }

    private func recordPermissionNoticeIfNeeded(appBundleIdentifier: String, now: Date) {
        lock.lock()
        let shouldRecord = lastPermissionNoticeAt.map { now.timeIntervalSince($0) > 30 } ?? true
        if shouldRecord {
            lastPermissionNoticeAt = now
        }
        lock.unlock()

        guard shouldRecord else {
            return
        }

        DiagnosticsLog.shared.record(
            "visible-page-context-blocked",
            metadata: [
                "app": appBundleIdentifier,
                "reason": "screen-recording-permission"
            ]
        )
    }

    private func captureImage(
        rect: CGRect,
        appBundleIdentifier: String,
        startedAt: Date
    ) -> CGImage? {
        let screenshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("autocomplete-visible-context-\(UUID().uuidString).png")
        defer {
            try? FileManager.default.removeItem(at: screenshotURL)
        }

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = [
                "-x",
                "-R\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width)),\(Int(rect.height))",
                screenshotURL.path
            ]
            try process.run()

            let timeout = Date().addingTimeInterval(1.2)
            while process.isRunning && Date() < timeout {
                Thread.sleep(forTimeInterval: 0.02)
            }

            if process.isRunning {
                process.terminate()
                DiagnosticsLog.shared.record(
                    "visible-page-context-capture-failed",
                    metadata: [
                        "app": appBundleIdentifier,
                        "reason": "timeout",
                        "durationMilliseconds": String(Self.milliseconds(from: startedAt, to: Date()))
                    ]
                )
                return nil
            }

            guard process.terminationStatus == 0,
                  let source = CGImageSourceCreateWithURL(screenshotURL as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                DiagnosticsLog.shared.record(
                    "visible-page-context-capture-failed",
                    metadata: [
                        "app": appBundleIdentifier,
                        "reason": "image-unreadable",
                        "status": String(process.terminationStatus),
                        "durationMilliseconds": String(Self.milliseconds(from: startedAt, to: Date()))
                    ]
                )
                return nil
            }

            return image
        } catch {
            DiagnosticsLog.shared.record(
                "visible-page-context-capture-failed",
                metadata: [
                    "app": appBundleIdentifier,
                    "reason": error.localizedDescription
                ]
            )
            return nil
        }
    }

    private func cacheKey(
        for focusedContext: FocusedTextContext,
        appBundleIdentifier: String
    ) -> CacheKey {
        CacheKey(
            bundleIdentifier: appBundleIdentifier,
            windowIdentifier: focusedContext.windowIdentifier,
            fieldIdentifier: focusedContext.elementIdentifier,
            rectSignature: Self.rectSignature(captureRect(for: focusedContext))
        )
    }

    private func captureRect(for focusedContext: FocusedTextContext) -> CGRect? {
        guard let baseRect = focusedContext.elementRect ?? focusedContext.windowRect else {
            return nil
        }

        let anchorRect = focusedContext.caretRect
            ?? focusedContext.textLineRect
            ?? focusedContext.elementRect
            ?? focusedContext.windowRect
            ?? baseRect

        let expanded = baseRect.insetBy(dx: -80, dy: -80)
        let width = min(maximumCaptureSize.width, expanded.width)
        let height = min(maximumCaptureSize.height, expanded.height)
        let centered = CGRect(
            x: anchorRect.midX - width / 2,
            y: anchorRect.midY - height / 2,
            width: width,
            height: height
        )
        let captureRect = expanded.intersection(centered).integral

        guard captureRect.width >= 80,
              captureRect.height >= 40 else {
            return nil
        }

        return captureRect
    }

    private static func rectSignature(_ rect: CGRect?) -> String {
        guard let rect else {
            return "missing"
        }

        return [
            Int(rect.origin.x / 20).description,
            Int(rect.origin.y / 20).description,
            Int(rect.width / 20).description,
            Int(rect.height / 20).description
        ].joined(separator: ":")
    }

    private static func milliseconds(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) * 1_000))
    }
}
