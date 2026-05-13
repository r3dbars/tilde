import Foundation

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
    public static let currentPolicyVersion = "2026-05-08.1"

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
            proofState: .partial,
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
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/obsidian.png")
            ],
            notes: "Real CodeMirror default, theme, and pane proof is recorded; long-note current-head proof remains blocked."
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
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/chrome-contenteditable.png"),
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/chrome-chat-like.png")
            ],
            notes: "Local fixtures and public text fields are proven; Google Docs, Notion, browser ChatGPT, Slack, Discord, official CodeMirror, and default Monaco remain blocked until exact proof exists."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.openai.codex",
            displayName: "Codex",
            hostVersion: .exact(shortVersion: "26.506.21252", build: "2575", source: "/Applications/Codex.app"),
            safetyMode: .wordOnly,
            runtimeState: .userToggleAllowed,
            proofState: .complete,
            killSwitch: .proofModeRequired,
            proofArtifacts: [
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/codex-inline.png"),
                HostProofArtifact(kind: "manual-smoke", reference: "Codex/default")
            ],
            notes: "Dogfood prompt support has same-slice screenshot, one-word accept, and no-submit proof. Full accept stays disabled until separate no-submit proof exists."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.anthropic.claude-code",
            displayName: "Claude Code",
            hostVersion: .exact(shortVersion: "2.1.128", build: "2.1.128", source: "/Users/redbars/Library/Application Support/Claude/claude-code/2.1.128/claude.app"),
            safetyMode: .disabled,
            runtimeState: .proofModeOnly,
            proofState: .complete,
            killSwitch: .proofModeRequired,
            proofArtifacts: [
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/claude-code-terminal.png"),
                HostProofArtifact(kind: "manual-smoke", reference: "Claude Code/default")
            ],
            notes: "Direct bundle is disabled; terminal-host proof is marker-gated and one-word only."
        ),
        HostCompatibilityPolicy(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            displayName: "Claude",
            hostVersion: .exact(shortVersion: "1.6608.0", build: "1.6608.0", source: "/Applications/Claude.app"),
            safetyMode: .wordOnly,
            runtimeState: .userToggleAllowed,
            proofState: .partial,
            killSwitch: .proofModeRequired,
            proofArtifacts: [
                HostProofArtifact(kind: "screenshot", reference: "docs/product/visual-placement-screenshots/claude-desktop.png")
            ],
            notes: "One prompt layout has no-submit proof; full accept and layout variants remain blocked."
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
