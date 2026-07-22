import AutocompleteLabCore
import Foundation

/// Privacy gate for anything that reaches the diagnostics log: values pass
/// through the metadata redactor so raw typed text can never be recorded.
enum RedactionLayer {
    static func logSafeValue(forKey key: String, value: String) -> String {
        DiagnosticsMetadataRedactor.logSafeValue(forKey: key, value: value)
    }
}
