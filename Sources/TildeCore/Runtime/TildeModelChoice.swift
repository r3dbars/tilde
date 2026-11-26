import Foundation

/// The immutable local models selectable in Tilde.
/// Gemma remains the conservative default; Qwen 4B is the compact balanced
/// option; Qwen 9B is the larger tier for Macs with more available memory.
public enum TildeModelChoice: String, CaseIterable, Equatable, Hashable, Sendable {
    case gemma4E2B = "gemma-4-e2b-q4km"
    case qwen35B4B = "qwen-3.5-4b-base-q4km"
    case qwen35B9B = "qwen-3.5-9b-base-q4km"

    public var displayName: String {
        switch self {
        case .gemma4E2B: "Gemma 4 E2B · Q4_K_M"
        case .qwen35B4B: "Qwen 3.5 4B Base · Q4_K_M"
        case .qwen35B9B: "Qwen 3.5 9B Base · Q4_K_M"
        }
    }

    public var shortName: String {
        switch self {
        case .gemma4E2B: "Gemma E2B"
        case .qwen35B4B: "Qwen 4B"
        case .qwen35B9B: "Qwen 9B"
        }
    }

    public var approximateSize: String {
        switch self {
        case .gemma4E2B: "3.43 GB"
        case .qwen35B4B: "2.71 GB"
        case .qwen35B9B: "5.63 GB"
        }
    }

    /// One honest line per model, shown in the setup and settings pickers.
    /// Gemma is the model every shipped measurement was taken on; Qwen options
    /// have not been through the full release-gate study, so the picker says
    /// that plainly.
    public var resourceGuidance: String {
        switch self {
        case .gemma4E2B: "Measured default, uses less memory and storage"
        case .qwen35B4B: "Compact and accurate, still under study"
        case .qwen35B9B: "Needs more memory and storage, still under study"
        }
    }

    public static func resolve(persistedValue: String?) -> Self {
        persistedValue.flatMap(Self.init(rawValue:)) ?? .gemma4E2B
    }
}
