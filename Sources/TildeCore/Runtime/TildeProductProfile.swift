import Foundation

/// Separates the daily driver from experimental, locally installed builds.
/// The profile is declared in each packaged bundle's Info.plist. Tests and
/// unbundled command-line tools intentionally fall back to production.
public enum TildeProductProfile: String, Equatable, Sendable {
    case production
    case preview26B = "preview-26b"
    case preview9B = "preview-9b"
    case modelPreview = "model-preview"

    public static let infoDictionaryKey = "TildeProductProfile"

    public static var current: Self {
        resolve(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            declaredProfile: Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String
        )
    }

    public static func resolve(bundleIdentifier: String?, declaredProfile: String?) -> Self {
        if let declaredProfile, let profile = Self(rawValue: declaredProfile) {
            return profile
        }
        switch bundleIdentifier {
        case "bar.r3d.tilde.preview26b", "bar.r3d.inputmethod.InlineGhostPreview26B":
            return .preview26B
        case "bar.r3d.tilde.preview9b", "bar.r3d.inputmethod.InlineGhostPreview9B":
            return .preview9B
        case "bar.r3d.tilde.modelpreview", "bar.r3d.inputmethod.InlineGhostModelPreview":
            return .modelPreview
        default:
            return .production
        }
    }

    public var appBundleIdentifier: String {
        switch self {
        case .production: "bar.r3d.tilde"
        case .preview26B: "bar.r3d.tilde.preview26b"
        case .preview9B: "bar.r3d.tilde.preview9b"
        case .modelPreview: "bar.r3d.tilde.modelpreview"
        }
    }

    public var inputMethodBundleIdentifier: String {
        switch self {
        case .production: "bar.r3d.inputmethod.InlineGhost"
        case .preview26B: "bar.r3d.inputmethod.InlineGhostPreview26B"
        case .preview9B: "bar.r3d.inputmethod.InlineGhostPreview9B"
        case .modelPreview: "bar.r3d.inputmethod.InlineGhostModelPreview"
        }
    }

    public var inputMethodConnectionName: String {
        switch self {
        case .production: "InlineGhostIME_1_Connection"
        case .preview26B: "InlineGhostIME_26B_Preview_Connection"
        case .preview9B: "InlineGhostIME_9B_Preview_Connection"
        case .modelPreview: "InlineGhostIME_Model_Preview_Connection"
        }
    }

    public var supportDirectoryName: String {
        switch self {
        case .production: "Tilde"
        case .preview26B: "Tilde 26B Preview"
        case .preview9B: "Tilde 9B Preview"
        case .modelPreview: "Tilde Model Preview"
        }
    }

    public var inputMethodInstalledBundleName: String {
        switch self {
        case .production: "InlineGhostIME.app"
        case .preview26B: "InlineGhostIME 26B Preview.app"
        case .preview9B: "InlineGhostIME 9B Preview.app"
        case .modelPreview: "InlineGhostIME Model Preview.app"
        }
    }

    public var displayName: String {
        switch self {
        case .production: "Tilde"
        case .preview26B: "Tilde 26B Preview"
        case .preview9B: "Tilde 9B Preview"
        case .modelPreview: "Tilde Model Preview"
        }
    }

    public var llamaServerPort: Int {
        switch self {
        case .production: 17_872
        case .preview26B: 17_874
        case .preview9B: 17_875
        case .modelPreview: 17_876
        }
    }

    public var generatedTokenBudget: Int {
        switch self {
        case .production: 20
        case .preview26B: 8
        case .preview9B: 12
        case .modelPreview: 8
        }
    }

    /// Lab-promoted completion controls remain isolated to the experimental
    /// 9B preview until they have enough real-world evidence for production.
    public var completionTemperature: Double {
        switch self {
        case .preview9B: 0.10
        case .production, .preview26B, .modelPreview: 0
        }
    }

    public var maximumVisibleWords: Int {
        switch self {
        case .preview9B: 3
        case .production, .preview26B, .modelPreview:
            CompletionSuggestion.defaultMaxVisibleWords
        }
    }

    /// Q12 nominated a 24-character scene-echo floor as a frozen validation
    /// candidate: at the shipped floor of 10 the detector coincides with a
    /// short visible-word cap and kills correct short verbatim answers. The
    /// word floor is unchanged — only the character floor was measured.
    /// Live in the isolated 9B preview only; this is not promotion.
    public var sceneEchoMinimumWords: Int {
        SceneEchoPolicy.defaultMinimumWords
    }

    public var sceneEchoMinimumCharacters: Int {
        switch self {
        case .preview9B: 24
        case .production, .preview26B, .modelPreview:
            SceneEchoPolicy.defaultMinimumCharacters
        }
    }

    /// Q12's second nominated candidate: refuse a suggestion that asserts a
    /// number, address, date, or name the writer never typed and the scene
    /// never showed. Off everywhere but the isolated 9B preview.
    public var factualGrounding: FactualGroundingPolicy.Mode {
        switch self {
        case .preview9B: .numbersAndNames
        case .production, .preview26B, .modelPreview: .off
        }
    }

    public var personalHistoryKeychainService: String {
        "\(appBundleIdentifier).personal-history"
    }

    public var personalHistoryAuthenticatedData: Data {
        Data("\(appBundleIdentifier).personal-history.v1".utf8)
    }
}
