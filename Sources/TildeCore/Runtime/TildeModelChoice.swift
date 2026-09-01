import Foundation

/// The two immutable local models supported by the official Tilde app.
/// Gemma remains the conservative default; Qwen is an owner-selected quality
/// tier for Macs with more available memory and storage.
public enum TildeModelChoice: String, CaseIterable, Equatable, Hashable, Sendable {
    case gemma4E2B = "gemma-4-e2b-q4km"
    case qwen35B9B = "qwen-3.5-9b-base-q4km"

    public var displayName: String {
        switch self {
        case .gemma4E2B: "Gemma 4 E2B · Q4_K_M"
        case .qwen35B9B: "Qwen 3.5 9B Base · Q4_K_M"
        }
    }

    public var shortName: String {
        switch self {
        case .gemma4E2B: "Gemma E2B"
        case .qwen35B9B: "Qwen 9B"
        }
    }

    public var approximateSize: String {
        switch self {
        case .gemma4E2B: "3.43 GB"
        case .qwen35B9B: "5.63 GB"
        }
    }

    public var resourceGuidance: String {
        switch self {
        case .gemma4E2B: "Lower resource use"
        case .qwen35B9B: "More memory and storage"
        }
    }

    public static func resolve(persistedValue: String?) -> Self {
        persistedValue.flatMap(Self.init(rawValue:)) ?? .gemma4E2B
    }
}
