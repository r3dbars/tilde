import AppKit
import AutocompleteLabCore
import CoreGraphics
import ImageIO
import ScreenCaptureKit
import Vision

final class VisiblePageContextProvider: @unchecked Sendable {
    static let shared = VisiblePageContextProvider()

    private struct CacheKey: Equatable {
        let bundleIdentifier: String
        let windowIdentifier: Int?
        let fieldIdentifier: Int
        let captureScope: VisiblePageContextCaptureScope
        let rectSignature: String
    }

    private struct CapturePlan {
        let rect: CGRect
        let scope: VisiblePageContextCaptureScope
    }

    private struct CacheEntry {
        let key: CacheKey
        let context: VisiblePageContext
        let capturedAt: Date
    }

    private final class CaptureResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var storedResult: Result<CGImage, Error>?

        func store(_ result: Result<CGImage, Error>) {
            lock.lock()
            storedResult = result
            lock.unlock()
        }

        func result() -> Result<CGImage, Error>? {
            lock.lock()
            defer { lock.unlock() }
            return storedResult
        }
    }

    private let queue = DispatchQueue(
        label: "app.transcripted.autocomplete.visible-page-context",
        qos: .utility
    )
    private let lock = NSLock()
    private let refreshPolicy = VisiblePageContextRefreshPolicy()
    private let maximumCaptureSize = CGSize(width: 1_600, height: 1_100)
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
              now.timeIntervalSince(cacheEntry.capturedAt) <= refreshPolicy.maximumCacheAge else {
            return nil
        }

        return cacheEntry.context
    }

    func refreshIfNeeded(
        for focusedContext: FocusedTextContext,
        app: RunningApplicationInfo,
        enabled: Bool,
        allowsFreshCacheRefresh: Bool = false,
        now: Date = Date()
    ) {
        guard enabled else {
            clear()
            return
        }
        guard !focusedContext.isSecure,
              focusedContext.selectedTextLength == 0,
              let capturePlan = capturePlan(for: focusedContext) else {
            return
        }

        guard CGPreflightScreenCaptureAccess() else {
            recordPermissionNoticeIfNeeded(appBundleIdentifier: app.bundleIdentifier, now: now)
            return
        }

        let key = cacheKey(for: focusedContext, appBundleIdentifier: app.bundleIdentifier)
        let activeTextLine = Self.activeTextLine(from: focusedContext.textBeforeCursor)
        guard reserveRefreshIfNeeded(
            key: key,
            allowsFreshCacheRefresh: allowsFreshCacheRefresh,
            now: now
        ) else {
            return
        }

        queue.async { [weak self] in
            self?.captureAndRecognize(
                plan: capturePlan,
                key: key,
                app: app,
                activeTextLine: activeTextLine,
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

    private func reserveRefreshIfNeeded(
        key: CacheKey,
        allowsFreshCacheRefresh: Bool,
        now: Date
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let matchingCacheAge = cacheEntry.flatMap { entry -> TimeInterval? in
            entry.key == key ? now.timeIntervalSince(entry.capturedAt) : nil
        }
        let lastAttemptAge = lastAttemptAt.map { now.timeIntervalSince($0) }

        guard refreshPolicy.shouldRefresh(
            inFlightMatchesKey: inFlightKey == key,
            matchingCacheAge: matchingCacheAge,
            lastAttemptAge: lastAttemptAge,
            allowsFreshCacheRefresh: allowsFreshCacheRefresh
        ) else {
            return false
        }

        lastAttemptAt = now
        inFlightKey = key
        return true
    }

    private func captureAndRecognize(
        plan: CapturePlan,
        key: CacheKey,
        app: RunningApplicationInfo,
        activeTextLine: String?,
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
            rect: plan.rect,
            appBundleIdentifier: app.bundleIdentifier,
            startedAt: startedAt
        ) else {
            return
        }

        // OCR knobs (env-tunable so the OCR-accuracy harness + research loop can
        // trade reading accuracy against speed). Defaults match the shipped app.
        let ocrEnv = ProcessInfo.processInfo.environment
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = (ocrEnv["STEADYTYPE_OCR_LEVEL"] == "fast") ? .fast : .accurate
        request.usesLanguageCorrection = (ocrEnv["STEADYTYPE_OCR_LANG_CORRECTION"] ?? "1") != "0"
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = ocrEnv["STEADYTYPE_OCR_MIN_TEXT_HEIGHT"].flatMap(Float.init) ?? 0.006

        do {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
        } catch {
            DiagnosticsLog.shared.record(
                "visible-page-context-ocr-failed",
                metadata: [
                    "app": app.bundleIdentifier,
                    "reason": error.localizedDescription
                ]
            )
            return
        }

        let recognizedText = request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n") ?? ""
        let rawLineCount = request.results?.count ?? 0

        guard let pageContext = VisiblePageContext(
            captureScope: plan.scope,
            activeApplicationName: app.localizedName,
            excludingActiveTextLine: activeTextLine,
            text: recognizedText
        ) else {
            DiagnosticsLog.shared.record(
                "visible-page-context-empty",
                metadata: [
                    "app": app.bundleIdentifier,
                    "captureScope": plan.scope.rawValue,
                    "rawLines": String(rawLineCount),
                    "imageWidth": String(image.width),
                    "imageHeight": String(image.height),
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
                "app": app.bundleIdentifier,
                "captureScope": plan.scope.rawValue,
                "chars": String(pageContext.text.count),
                "lines": pageContext.traceMetadata["visiblePageContextLines"] ?? "0",
                "activeLineFiltered": String(pageContext.activeTextLineFiltered),
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
        if let image = captureImageWithScreenCaptureKit(
            rect: rect,
            appBundleIdentifier: appBundleIdentifier,
            startedAt: startedAt
        ) {
            return image
        }

        return captureImageWithScreencaptureProcess(
            rect: rect,
            appBundleIdentifier: appBundleIdentifier,
            startedAt: startedAt
        )
    }

    private func captureImageWithScreenCaptureKit(
        rect: CGRect,
        appBundleIdentifier: String,
        startedAt: Date
    ) -> CGImage? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = CaptureResultBox()

        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )
                guard let display = Self.screenCaptureDisplay(
                    containing: rect,
                    displays: content.displays
                ) else {
                    throw VisiblePageContextCaptureError.missingDisplay
                }

                let displayRect = display.frame
                let sourceRect = rect.intersection(displayRect).integral
                guard sourceRect.width >= 80,
                      sourceRect.height >= 40 else {
                    throw VisiblePageContextCaptureError.invalidSourceRect
                }

                let scale = Self.backingScaleFactor(for: displayRect)
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let configuration = SCStreamConfiguration()
                configuration.sourceRect = sourceRect
                configuration.width = max(1, Int(sourceRect.width * scale))
                configuration.height = max(1, Int(sourceRect.height * scale))
                configuration.showsCursor = false

                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: configuration
                )
                box.store(.success(image))
            } catch {
                box.store(.failure(error))
            }

            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + 1.5) == .success else {
            DiagnosticsLog.shared.record(
                "visible-page-context-capture-failed",
                metadata: [
                    "app": appBundleIdentifier,
                    "source": "screencapturekit",
                    "reason": "timeout",
                    "durationMilliseconds": String(Self.milliseconds(from: startedAt, to: Date()))
                ]
            )
            return nil
        }

        switch box.result() {
        case let .success(image):
            return image
        case let .failure(error):
            DiagnosticsLog.shared.record(
                "visible-page-context-capture-failed",
                metadata: [
                    "app": appBundleIdentifier,
                    "source": "screencapturekit",
                    "reason": error.localizedDescription,
                    "durationMilliseconds": String(Self.milliseconds(from: startedAt, to: Date()))
                ]
            )
            return nil
        case nil:
            return nil
        }
    }

    private func captureImageWithScreencaptureProcess(
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
            process.waitUntilExit()

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

    private enum VisiblePageContextCaptureError: LocalizedError {
        case missingDisplay
        case invalidSourceRect

        var errorDescription: String? {
            switch self {
            case .missingDisplay:
                "No capture display matched the focused text field."
            case .invalidSourceRect:
                "The capture region was too small."
            }
        }
    }

    private static func screenCaptureDisplay(
        containing rect: CGRect,
        displays: [SCDisplay]
    ) -> SCDisplay? {
        let point = CGPoint(x: rect.midX, y: rect.midY)
        return displays.first { $0.frame.contains(point) }
            ?? displays.first { $0.frame.intersects(rect) }
            ?? displays.first
    }

    private static func backingScaleFactor(for displayRect: CGRect) -> CGFloat {
        NSScreen.screens.first { $0.frame.intersects(displayRect) }?
            .backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private func cacheKey(
        for focusedContext: FocusedTextContext,
        appBundleIdentifier: String
    ) -> CacheKey {
        CacheKey(
            bundleIdentifier: appBundleIdentifier,
            windowIdentifier: focusedContext.windowIdentifier,
            fieldIdentifier: focusedContext.elementIdentifier,
            captureScope: capturePlan(for: focusedContext)?.scope ?? .focusedRegion,
            rectSignature: Self.rectSignature(capturePlan(for: focusedContext)?.rect)
        )
    }

    private func capturePlan(for focusedContext: FocusedTextContext) -> CapturePlan? {
        guard let baseRect = focusedContext.elementRect ?? focusedContext.windowRect else {
            return nil
        }

        let anchorRect = focusedContext.caretRect
            ?? focusedContext.textLineRect
            ?? focusedContext.elementRect
            ?? focusedContext.windowRect
            ?? baseRect

        if let visibleScreenRect = visibleScreenRect(containing: anchorRect) ?? visibleScreenRect(containing: baseRect) {
            let screenRect = visibleScreenRect.integral
            if screenRect.width <= maximumCaptureSize.width,
               screenRect.height <= maximumCaptureSize.height {
                return CapturePlan(rect: screenRect, scope: .visibleScreen)
            }

            let centered = CGRect(
                x: anchorRect.midX - maximumCaptureSize.width / 2,
                y: anchorRect.midY - maximumCaptureSize.height / 2,
                width: maximumCaptureSize.width,
                height: maximumCaptureSize.height
            )
            let clamped = Self.clamped(centered, to: screenRect).integral
            if clamped.width >= 80,
               clamped.height >= 40 {
                return CapturePlan(rect: clamped, scope: .visibleScreen)
            }
        }

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

        return CapturePlan(rect: captureRect, scope: .focusedRegion)
    }

    private func visibleScreenRect(containing rect: CGRect) -> CGRect? {
        let point = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens
            .map(\.visibleFrame)
            .first { $0.contains(point) }
    }

    private static func clamped(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        let width = min(rect.width, bounds.width)
        let height = min(rect.height, bounds.height)
        let minX = bounds.minX
        let maxX = bounds.maxX - width
        let minY = bounds.minY
        let maxY = bounds.maxY - height
        return CGRect(
            x: min(max(rect.origin.x, minX), maxX),
            y: min(max(rect.origin.y, minY), maxY),
            width: width,
            height: height
        )
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

    private static func activeTextLine(from textBeforeCursor: String) -> String? {
        let line = textBeforeCursor
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .last
            .map(String.init) ?? textBeforeCursor
        let trimmed = line
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 4 else {
            return nil
        }

        return trimmed
    }

    private static func milliseconds(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) * 1_000))
    }
}
