import Foundation

public enum DiagnosticValueRedactor {
    public static func stringSummary(length: Int) -> String {
        "String(\(length) chars)"
    }

    public static func attributedStringSummary(length: Int) -> String {
        "AttributedString(\(length) chars)"
    }

    public static func arraySummary(count: Int) -> String {
        "Array(\(count) items)"
    }

    public static func unknownSummary(typeName: String) -> String {
        "\(typeName)(redacted)"
    }
}
