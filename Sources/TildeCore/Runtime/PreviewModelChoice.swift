import Foundation

/// The small, explicit set of experimental models the model-preview build can
/// run. Production never consults this setting and remains pinned to E2B.
public enum PreviewModelChoice: String, CaseIterable, Equatable, Hashable, Sendable {
    case qwen35B9B = "qwen-3.5-9b-base-q4km"
    case gemma426B = "gemma-4-26b-a4b-base-q4km"

    public var displayName: String {
        switch self {
        case .qwen35B9B: "Qwen 3.5 9B Base · Q4_K_M"
        case .gemma426B: "Gemma 4 26B A4B Base · Q4_K_M"
        }
    }

    public var shortName: String {
        switch self {
        case .qwen35B9B: "Qwen 9B"
        case .gemma426B: "Gemma 26B"
        }
    }

    public var approximateSize: String {
        switch self {
        case .qwen35B9B: "5.63 GB"
        case .gemma426B: "16.80 GB"
        }
    }

    public static func resolve(persistedValue: String?) -> Self {
        persistedValue.flatMap(Self.init(rawValue:)) ?? .qwen35B9B
    }
}
