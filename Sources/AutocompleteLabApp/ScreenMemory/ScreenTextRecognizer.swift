import AutocompleteLabCore
import CoreGraphics
import Vision

/// Runs on-device Vision OCR over a single captured frame. Accurate mode
/// only — Screen Memory triggers are cadence-capped to 1/2s already, so
/// there is no throughput pressure pushing toward the faster, less precise
/// `.fast` recognition level.
enum ScreenTextRecognizer {
    struct RecognizedBlock: Equatable, Sendable {
        let text: String
        /// Top-left-origin, normalized to the full image — already flipped
        /// from Vision's native bottom-left convention so every consumer
        /// downstream of this type shares one coordinate convention.
        let boundingBox: NormalizedDisplayRect
    }

    enum RecognitionError: Error {
        case requestFailed
    }

    static func recognize(image: CGImage) async throws -> [RecognizedBlock] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: RecognitionError.requestFailed)
                    return
                }
                let blocks = observations.compactMap { observation -> RecognizedBlock? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedBlock(
                        text: candidate.string,
                        boundingBox: Self.topLeftNormalized(observation.boundingBox)
                    )
                }
                continuation.resume(returning: blocks)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Vision reports `boundingBox` normalized with origin bottom-left; the
    /// rest of Screen Memory (window frames, `NormalizedDisplayRect`) standardizes
    /// on top-left, matching Quartz/ScreenCaptureKit's global-coordinate
    /// convention. Flip once, here, so nothing downstream has to remember
    /// which convention it is holding.
    private static func topLeftNormalized(_ box: CGRect) -> NormalizedDisplayRect {
        NormalizedDisplayRect(
            x: box.origin.x,
            y: 1.0 - box.origin.y - box.height,
            width: box.width,
            height: box.height
        )
    }
}
