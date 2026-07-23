// Standalone OCR probe: runs the app's exact Vision text-recognition settings
// (same STEADYTYPE_OCR_* env knobs) on an image and prints the recognized text.
// Used by script/ocr_eval.py to measure reading accuracy vs known ground truth.
//   swift script/ocr_probe.swift <image-path>
import Foundation
import Vision
import AppKit

let args = CommandLine.arguments
guard args.count > 1 else {
    FileHandle.standardError.write("usage: ocr_probe <image-path>\n".data(using: .utf8)!)
    exit(2)
}
guard let image = NSImage(contentsOfFile: args[1]),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("could not load image\n".data(using: .utf8)!)
    exit(3)
}

let env = ProcessInfo.processInfo.environment
let request = VNRecognizeTextRequest()
request.recognitionLevel = (env["STEADYTYPE_OCR_LEVEL"] == "fast") ? .fast : .accurate
request.usesLanguageCorrection = (env["STEADYTYPE_OCR_LANG_CORRECTION"] ?? "1") != "0"
request.recognitionLanguages = ["en-US"]
request.minimumTextHeight = env["STEADYTYPE_OCR_MIN_TEXT_HEIGHT"].flatMap(Float.init) ?? 0.006

let handler = VNImageRequestHandler(cgImage: cg, options: [:])
do {
    try handler.perform([request])
} catch {
    FileHandle.standardError.write("ocr failed: \(error)\n".data(using: .utf8)!)
    exit(4)
}
let text = (request.results ?? [])
    .compactMap { $0.topCandidates(1).first?.string }
    .joined(separator: "\n")
print(text)
