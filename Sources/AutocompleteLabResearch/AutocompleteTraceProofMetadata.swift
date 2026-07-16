import Foundation
import AutocompleteLabCore

public enum AutocompleteTraceProofMetadata {
    public static let traceProofVersion = "2026-05-07.1"
    public static let placementProofVersion = "placement-v4"
    public static let keyCaptureProofVersion = "key-capture-v3"
    public static let runtimeProofVersion = "runtime-v2"

    public static let requiredKeys = [
        "traceProofVersion",
        "placementProofVersion",
        "keyCaptureProofVersion",
        "runtimeProofVersion"
    ]

    public static var current: [String: String] {
        [
            "traceProofVersion": traceProofVersion,
            "placementProofVersion": placementProofVersion,
            "keyCaptureProofVersion": keyCaptureProofVersion,
            "runtimeProofVersion": runtimeProofVersion
        ]
    }

    public static func isCurrent(_ metadata: [String: String]) -> Bool {
        current.allSatisfy { key, value in
            metadata[key] == value
        }
    }
}
