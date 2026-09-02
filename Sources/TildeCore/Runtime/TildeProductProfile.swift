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

    /// Qwen's validated completion controls are shared by its official model
    /// choice and the isolated 9B preview identity.
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
    /// Shared by the official Qwen choice and the isolated 9B preview.
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

    /// Q12's second quality gate: refuse a suggestion that asserts a
    /// number, address, date, or name the writer never typed and the scene
    /// never showed. Applied to the official Qwen choice and 9B preview.
    public var factualGrounding: FactualGroundingPolicy.Mode {
        switch self {
        case .preview9B: .numbersAndNames
        case .production, .preview26B, .modelPreview: .off
        }
    }

    /// Pre-inference scene gate selection. The 9B preview reads the reply
    /// cue off the writer's current sentence (owner-directed 2026-09-01);
    /// every other profile keeps the measured production gate.
    public var sceneSuggestionOptions: SceneSuggestionPolicy.Options {
        switch self {
        case .preview9B: SceneSuggestionPolicy.Options(replyCueAnchoredToCurrentSentence: true)
        case .production, .preview26B, .modelPreview: .production
        }
    }

    /// Whether the Conversation block opens with the source window's title
    /// (owner-directed 2026-09-01, 9B preview only). Production prompts
    /// stay byte-identical until a context campaign promotes it.
    public var includesWindowTitleInScene: Bool {
        self == .preview9B
    }

    /// After the writer accepts the last visible word (or the whole ghost),
    /// request the next continuation at once instead of waiting for the
    /// next keystroke, so a sentence can be completed Tab by Tab at the
    /// three-word precision the lab has measured. Owner-directed for the 9B
    /// preview (2026-09-01); an interaction change, so it stays out of
    /// production until the live acceptance and retention numbers hold.
    public var chainsCompletionAfterAccept: Bool {
        self == .preview9B
    }

    /// Reveal floor for Chromium/Electron hosts. The 9B preview trials the
    /// shorter pair (owner-directed 2026-09-02); production keeps the
    /// measured floor until the real-host matrix clears the change.
    public var calmRevealDelays: SuggestionRevealDelayPolicy.CalmDelays {
        self == .preview9B ? .preview : .production
    }

    /// Whether sentence and clause punctuation is a request boundary. In
    /// production a period, comma, or question mark hides the ghost and
    /// nothing is asked until the next letter, which is the dead zone at
    /// exactly the moment a thought turns. The 9B preview asks there too
    /// (owner-directed 2026-09-02); the ghost carries its own separator.
    public var requestsAfterPunctuation: Bool {
        self == .preview9B
    }

    public var personalHistoryKeychainService: String {
        "\(appBundleIdentifier).personal-history"
    }

    public var personalHistoryAuthenticatedData: Data {
        Data("\(appBundleIdentifier).personal-history.v1".utf8)
    }
}
