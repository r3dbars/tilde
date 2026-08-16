#!/usr/bin/env swift
// Manual probe for Screen Memory's Phase 1 capture engine. Not part of any
// automated proof: this is the only way to eyeball two things unit tests
// cannot check without a live display and a granted TCC permission —
//   1. Vision OCR quality on a real screen (fonts, contrast, Retina scale).
//   2. Whether sorting SCShareableContent.windows by windowLayer really does
//      give a front-to-back order that survives real overlapping windows
//      (Apple documents no ordering guarantee for that array — see
//      Sources/AutocompleteLabApp/ScreenMemory/ScreenCaptureService.swift).
// Real caller: Phase 1b's battery/latency measurements and Phase 4's OCR
// quality checks both start from a human running this and reading the
// output, per docs/plans/screen-memory.md.
//
// Usage: swift script/screen_capture_probe.swift
// Requires Screen Recording permission for whatever runs this (Terminal,
// or your IDE) — macOS will prompt on first run if not already granted.
//
// Prints to stdout only — this is an interactive tool an operator reads
// directly, not a log file or report. It writes nothing to disk, matching
// the covenant's "no raw screen text in logs, diagnostics, or any report."

import CoreGraphics
import Foundation
import ScreenCaptureKit
import Vision

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("Error: " + message + "\n").utf8))
    exit(1)
}

func topLeftNormalizedBox(_ box: CGRect) -> CGRect {
    // Vision reports boundingBox normalized with origin bottom-left; flip to
    // top-left to match ScreenCaptureService's convention for this printout.
    CGRect(x: box.origin.x, y: 1.0 - box.origin.y - box.height, width: box.width, height: box.height)
}

func normalize(_ frame: CGRect, in displayFrame: CGRect) -> CGRect {
    guard displayFrame.width > 0, displayFrame.height > 0 else { return .zero }
    return CGRect(
        x: (frame.origin.x - displayFrame.origin.x) / displayFrame.width,
        y: (frame.origin.y - displayFrame.origin.y) / displayFrame.height,
        width: frame.width / displayFrame.width,
        height: frame.height / displayFrame.height
    )
}

func recognizeText(in image: CGImage) throws -> [(text: String, box: CGRect)] {
    var result: [(String, CGRect)] = []
    var caughtError: Error?
    let semaphore = DispatchSemaphore(value: 0)
    let request = VNRecognizeTextRequest { request, error in
        defer { semaphore.signal() }
        if let error { caughtError = error; return }
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            result.append((candidate.string, topLeftNormalizedBox(observation.boundingBox)))
        }
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])
    semaphore.wait()
    if let caughtError { throw caughtError }
    return result
}

print("Screen Memory capture probe — Phase 1a manual verification")
print(String(repeating: "-", count: 60))

guard CGPreflightScreenCaptureAccess() else {
    print("Screen Recording permission not granted. Requesting…")
    _ = CGRequestScreenCaptureAccess()
    fail("Grant Screen Recording to your terminal/IDE in System Settings, then re-run.")
}

let contentSemaphore = DispatchSemaphore(value: 0)
var content: SCShareableContent?
var contentError: Error?
SCShareableContent.getWithCompletionHandler { shareableContent, error in
    content = shareableContent
    contentError = error
    contentSemaphore.signal()
}
contentSemaphore.wait()

if let contentError {
    fail("SCShareableContent failed: \(contentError.localizedDescription)")
}
guard let content, let display = content.displays.first else {
    fail("No capturable display returned. Is Screen Recording actually granted?")
}

print("Display: \(display.displayID), \(display.width)x\(display.height) pt")
print("On-screen windows: \(content.windows.count)")
print("")

let startedAt = Date()

let filter = SCContentFilter(display: display, excludingWindows: [])
let configuration = SCStreamConfiguration()
configuration.width = display.width
configuration.height = display.height
configuration.showsCursor = false

let captureSemaphore = DispatchSemaphore(value: 0)
var capturedImage: CGImage?
var captureError: Error?
Task {
    do {
        capturedImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    } catch {
        captureError = error
    }
    captureSemaphore.signal()
}
captureSemaphore.wait()

if let captureError {
    fail("Capture failed: \(captureError.localizedDescription)")
}
guard let capturedImage else {
    fail("Capture returned no image.")
}
let capturedAt = Date()
print(String(format: "Capture took %.0fms", capturedAt.timeIntervalSince(startedAt) * 1000))

let blocks: [(text: String, box: CGRect)]
do {
    blocks = try recognizeText(in: capturedImage)
} catch {
    fail("Vision OCR failed: \(error.localizedDescription)")
}
let ocrDoneAt = Date()
print(String(format: "OCR took %.0fms, found %d blocks", ocrDoneAt.timeIntervalSince(capturedAt) * 1000, blocks.count))
print("")

// `windowLayer` is ScreenCaptureService's chosen front-to-back proxy since
// Apple documents no ordering for `SCShareableContent.windows` itself. This
// probe existing is exactly how that choice gets checked against reality.
let frontToBackWindows = content.windows.sorted { $0.windowLayer < $1.windowLayer }
struct WindowInfo { let bundleIdentifier: String?; let title: String?; let frame: CGRect }
let windows = frontToBackWindows.map {
    WindowInfo(
        bundleIdentifier: $0.owningApplication?.bundleIdentifier,
        title: $0.title,
        frame: normalize($0.frame, in: display.frame)
    )
}

func attribute(_ box: CGRect) -> WindowInfo? {
    let centerX = box.midX
    let centerY = box.midY
    return windows.first { window in
        centerX >= window.frame.minX && centerX <= window.frame.maxX
            && centerY >= window.frame.minY && centerY <= window.frame.maxY
    }
}

print("Windows (front-to-back, by windowLayer):")
for window in windows.prefix(15) {
    let owner = window.bundleIdentifier ?? "(no owner)"
    let title = window.title ?? "(no title)"
    print("  \(owner) — \(title) — frame \(window.frame)")
}
if windows.count > 15 { print("  … and \(windows.count - 15) more") }
print("")

print("OCR blocks with window attribution:")
for (text, box) in blocks.prefix(40) {
    let owner = attribute(box)?.bundleIdentifier ?? "(unattributed)"
    let snippet = text.count > 60 ? String(text.prefix(60)) + "…" : text
    print("  [\(owner)] \(snippet)")
}
if blocks.count > 40 { print("  … and \(blocks.count - 40) more blocks") }

print("")
print("Reminder: this prints your own screen's text to your own terminal only —")
print("nothing here is written to a file, logged, or sent anywhere. Do not paste")
print("this output somewhere else without checking what it captured first.")
print("If OCR quality looks poor, check display scaling and font contrast first —")
print("PR 1b's job is measuring and tuning capture resolution/cadence, not this probe.")
