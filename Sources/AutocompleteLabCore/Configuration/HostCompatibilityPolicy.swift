import Foundation

// Per-host safety/proof MIRROR — not the live runtime authority.
//
// Runtime "where to suggest / where to insert / what acceptance mode" decisions are made by
// `CompatibilityProfile` / `CompatibilityProfileStore` (promptAppSafetyMode, canPresentSuggestions,
// isSensitive) plus the denylist and `SensitiveTextFieldPolicy`. This catalog restates the same per-host
// posture in proof terms and adds proof-tracking metadata (exact/pending host version, proofState,
// killSwitch, proofArtifacts).
//
// Its consumers are the proof system, not the app loop:
//   - `HostCompatibilityPolicyTests` cross-checks it against `CompatibilityProfileStore.mvp` so the two can
//     never drift (e.g. `safetyMode == promptAppSafetyMode`, send surfaces are never `.notPrompt`).
//
// Because nothing in `AutocompleteLabApp` references it, it is classified `proof-only` in
// `docs/product/public-core-reachability-allowlist.psv`. Keep it in sync with the live profile store rather
// than wiring a second runtime source of truth.

public enum HostPolicyRuntimeState: String, Equatable, Sendable {
    case userToggleAllowed
    case proofModeOnly
    case diagnosticsOnly
    case disabled

    public func allowsSuggestions(userDisabled: Bool, proofModeEnabled: Bool) -> Bool {
        switch self {
        case .userToggleAllowed:
            return !userDisabled
        case .proofModeOnly:
            return proofModeEnabled && !userDisabled
        case .diagnosticsOnly, .disabled:
            return false
        }
    }
}

public enum HostPolicyProofState: String, Equatable, Sendable {
    case complete
    case partial
    case blocked
    case pending
}

public enum HostPolicyKillSwitch: String, Equatable, Sendable {
    case none
    case perHostDisable
    case proofModeRequired
    case diagnosticsOnly
    case hardDisabled
}

public enum HostAppVersionProof: Equatable, Sendable {
    case exact(shortVersion: String, build: String, source: String)
    case pending(reason: String)

    public var isExact: Bool {
        switch self {
        case .exact:
            return true
        case .pending:
            return false
        }
    }
}

public struct HostProofArtifact: Equatable, Sendable {
    public let kind: String
    public let reference: String

    public init(kind: String, reference: String) {
        self.kind = kind
        self.reference = reference
    }
}

public struct HostCompatibilityPolicy: Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let hostVersion: HostAppVersionProof
    public let safetyMode: PromptAppSafetyMode
    public let runtimeState: HostPolicyRuntimeState
    public let proofState: HostPolicyProofState
    public let killSwitch: HostPolicyKillSwitch
    public let proofArtifacts: [HostProofArtifact]
    public let notes: String

    public init(
        bundleIdentifier: String,
        displayName: String,
        hostVersion: HostAppVersionProof,
        safetyMode: PromptAppSafetyMode,
        runtimeState: HostPolicyRuntimeState,
        proofState: HostPolicyProofState,
        killSwitch: HostPolicyKillSwitch,
        proofArtifacts: [HostProofArtifact] = [],
        notes: String
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.hostVersion = hostVersion
        self.safetyMode = safetyMode
        self.runtimeState = runtimeState
        self.proofState = proofState
        self.killSwitch = killSwitch
        self.proofArtifacts = proofArtifacts
        self.notes = notes
    }
}

public struct HostCompatibilityPolicyCatalog: Equatable, Sendable {
    public static let currentPolicyVersion = "2026-05-31.1"

    public let policyVersion: String
    public let policies: [String: HostCompatibilityPolicy]

    public init(
        policyVersion: String = Self.currentPolicyVersion,
        policies: [HostCompatibilityPolicy]
    ) {
        self.policyVersion = policyVersion
        self.policies = Dictionary(uniqueKeysWithValues: policies.map { ($0.bundleIdentifier, $0) })
    }

    public func policy(for bundleIdentifier: String) -> HostCompatibilityPolicy? {
        policies[bundleIdentifier]
    }

    public static let mvp = HostCompatibilityPolicyCatalog(policies: [
        HostCompatibilityPolicy(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            hostVersion: .exact(shortVersion: "1.20", build: "415", source: "/System/Applications/TextEdit.app"),
            safetyMode: .notPrompt,
            runtimeState: .userToggleAllowed,
            proofState: .complete,
            killSwitch: .perHostDisable,
            proofArtifacts: [
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/textedit-inline.png"),
                HostProofArtifact(kind: "manual-smoke", reference: "TextEdit/default")
            ],
            notes: "Reference native target with recorded strict visual and insertion proof; current-head freshness is checked separately."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.apple.Notes",
            displayName: "Notes",
            hostVersion: .exact(shortVersion: "4.13", build: "3146.101.28", source: "/System/Applications/Notes.app"),
            safetyMode: .notPrompt,
            runtimeState: .userToggleAllowed,
            proofState: .complete,
            killSwitch: .perHostDisable,
            proofArtifacts: [
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/notes-title.png"),
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/notes-body.png"),
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/notes-checklist.png")
            ],
            notes: "Rich-text proof is split by title, body, and checklist lanes."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "md.obsidian",
            displayName: "Obsidian",
            hostVersion: .exact(shortVersion: "1.12.4", build: "0.14.8", source: "/Applications/Obsidian.app"),
            safetyMode: .notPrompt,
            runtimeState: .userToggleAllowed,
            proofState: .partial,
            killSwitch: .perHostDisable,
            proofArtifacts: [
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/obsidian.png"),
                HostProofArtifact(kind: "manual-smoke", reference: "Obsidian/obsidian-long-note")
            ],
            notes: "Theme, pane, and long-note proof is recorded; stock no-flags default proof is tracked separately before claiming stock Obsidian support."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail",
            hostVersion: .exact(shortVersion: "16.0", build: "3864.500.181", source: "/System/Applications/Mail.app"),
            safetyMode: .notPrompt,
            runtimeState: .diagnosticsOnly,
            proofState: .blocked,
            killSwitch: .diagnosticsOnly,
            notes: "Sensitive compose surface; suggestions remain off until insertion proof exists."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.apple.MobileSMS",
            displayName: "Messages",
            hostVersion: .exact(shortVersion: "26.0", build: "1450.600.61.1.4", source: "/System/Applications/Messages.app"),
            safetyMode: .wordOnly,
            runtimeState: .proofModeOnly,
            proofState: .partial,
            killSwitch: .proofModeRequired,
            proofArtifacts: [
                HostProofArtifact(kind: "manual-smoke", reference: "Messages/default")
            ],
            notes: "AXTextField chat compose has partial one-word proof only. Normal support stays off; explicit proof mode is required and full accept stays off."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.openai.atlas",
            displayName: "ChatGPT Atlas",
            hostVersion: .exact(shortVersion: "1.2026.112.0", build: "20260422141901000", source: "/Applications/ChatGPT Atlas.app"),
            safetyMode: .disabled,
            runtimeState: .disabled,
            proofState: .blocked,
            killSwitch: .hardDisabled,
            notes: "Prompt/browser hybrid stays disabled until disposable prompt and page-field proof exists."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.openai.chat",
            displayName: "ChatGPT",
            hostVersion: .pending(reason: "App not installed or not proofed on this host."),
            safetyMode: .disabled,
            runtimeState: .disabled,
            proofState: .blocked,
            killSwitch: .hardDisabled,
            notes: "Prompt composer can submit or attach context; exact-version no-submit proof is required."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.openai.ChatGPT",
            displayName: "ChatGPT",
            hostVersion: .pending(reason: "Alternate bundle ID not installed or not proofed on this host."),
            safetyMode: .disabled,
            runtimeState: .disabled,
            proofState: .blocked,
            killSwitch: .hardDisabled,
            notes: "Prompt composer can submit or attach context; exact-version no-submit proof is required."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Chrome",
            hostVersion: .exact(shortVersion: "148.0.7778.96", build: "7778.96", source: "/Applications/Google Chrome.app"),
            safetyMode: .notPrompt,
            runtimeState: .userToggleAllowed,
            proofState: .partial,
            killSwitch: .perHostDisable,
            proofArtifacts: [
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/chrome-textarea.png"),
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/chrome-contenteditable.png")
            ],
            notes: "Only local textarea and local contenteditable fixtures are beta-safe. Public pages, production browser apps, browser ChatGPT, Slack, Discord, Google Docs, Notion, official CodeMirror, and default Monaco remain blocked until exact proof exists."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.openai.codex",
            displayName: "Codex",
            hostVersion: .exact(shortVersion: "26.519.22136", build: "3003", source: "/Applications/Codex.app"),
            safetyMode: .wordOnly,
            runtimeState: .userToggleAllowed,
            proofState: .partial,
            killSwitch: .perHostDisable,
            proofArtifacts: [
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/codex-inline.png"),
                HostProofArtifact(kind: "manual-smoke", reference: "Codex/default"),
                HostProofArtifact(kind: "manual-smoke", reference: "Codex/full-accept")
            ],
            notes: "Enabled for this local Codex build with one-word and full-accept no-submit proof. Detached suggestions and generic key-event insertion stay off."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.anthropic.claude-code",
            displayName: "Claude Code",
            hostVersion: .exact(shortVersion: "2.1.128", build: "2.1.128", source: "/Users/redbars/Library/Application Support/Claude/claude-code/2.1.128/claude.app"),
            safetyMode: .wordOnly,
            runtimeState: .userToggleAllowed,
            proofState: .partial,
            killSwitch: .perHostDisable,
            proofArtifacts: [
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/claude-code-terminal.png"),
                HostProofArtifact(kind: "manual-smoke", reference: "Claude Code/default")
            ],
            notes: "Default-on dogfood lane; terminal-host support is Claude-detected and one-word only."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            displayName: "Claude",
            hostVersion: .exact(shortVersion: "1.6608.0", build: "1.6608.0", source: "/Applications/Claude.app"),
            safetyMode: .wordOnly,
            runtimeState: .userToggleAllowed,
            proofState: .partial,
            killSwitch: .perHostDisable,
            proofArtifacts: [
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/claude-desktop.png")
            ],
            notes: "Default-on dogfood lane with one-word no-submit behavior; layout variants will be fixed from screenshots."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            hostVersion: .pending(reason: "Exact Safari build not captured in this proof pass."),
            safetyMode: .disabled,
            runtimeState: .disabled,
            proofState: .blocked,
            killSwitch: .hardDisabled,
            notes: "WebKit rich-editor and prompt surfaces need exact-version proof first."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            displayName: "Slack",
            hostVersion: .pending(reason: "Slack not proofed on this host."),
            safetyMode: .disabled,
            runtimeState: .disabled,
            proofState: .blocked,
            killSwitch: .hardDisabled,
            notes: "Message composer stays disabled until no-submit proof exists."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "ru.keepcoder.Telegram",
            displayName: "Telegram",
            hostVersion: .pending(reason: "Telegram not proofed on this host."),
            safetyMode: .disabled,
            runtimeState: .disabled,
            proofState: .blocked,
            killSwitch: .hardDisabled,
            notes: "Send-by-enter variants need disposable chat proof before suggestions run."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "notion.id",
            displayName: "Notion",
            hostVersion: .pending(reason: "Notion not proofed on this host."),
            safetyMode: .notPrompt,
            runtimeState: .disabled,
            proofState: .blocked,
            killSwitch: .hardDisabled,
            notes: "Workspace text and ProseMirror placement need disposable-page proof."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.hnc.Discord",
            displayName: "Discord",
            hostVersion: .pending(reason: "Discord not proofed on this host."),
            safetyMode: .disabled,
            runtimeState: .disabled,
            proofState: .blocked,
            killSwitch: .hardDisabled,
            notes: "Composer stays disabled until no-submit proof exists."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.hnc.DiscordPTB",
            displayName: "Discord PTB",
            hostVersion: .pending(reason: "Discord PTB not proofed on this host."),
            safetyMode: .disabled,
            runtimeState: .disabled,
            proofState: .blocked,
            killSwitch: .hardDisabled,
            notes: "Composer stays disabled until no-submit proof exists."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.hnc.DiscordCanary",
            displayName: "Discord Canary",
            hostVersion: .pending(reason: "Discord Canary not proofed on this host."),
            safetyMode: .disabled,
            runtimeState: .disabled,
            proofState: .blocked,
            killSwitch: .hardDisabled,
            notes: "Composer stays disabled until no-submit proof exists."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "VS Code",
            hostVersion: .pending(reason: "VS Code is denylisted and not proofed."),
            safetyMode: .notPrompt,
            runtimeState: .disabled,
            proofState: .blocked,
            killSwitch: .hardDisabled,
            notes: "Monaco editor and command surface stay blocked until app-specific proof exists."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            displayName: "Cursor",
            hostVersion: .pending(reason: "Cursor is denylisted and not proofed."),
            safetyMode: .notPrompt,
            runtimeState: .disabled,
            proofState: .blocked,
            killSwitch: .hardDisabled,
            notes: "Monaco editor and AI composer stay blocked until app-specific proof exists."
        )
    ])
}
