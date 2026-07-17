import Testing
@testable import AutocompleteLabCore

@Suite("Host compatibility policy")
struct HostCompatibilityPolicyTests {
    @Test("Host policy covers every compatibility profile")
    func hostPolicyCoversEveryCompatibilityProfile() throws {
        let profiles = CompatibilityProfileStore.mvp.profiles
        let catalog = HostCompatibilityPolicyCatalog.mvp

        #expect(catalog.policyVersion == HostCompatibilityPolicyCatalog.currentPolicyVersion)
        #expect(Set(catalog.policies.keys) == Set(profiles.keys))

        for (bundleIdentifier, profile) in profiles {
            let policy = try #require(catalog.policy(for: bundleIdentifier))
            #expect(policy.displayName == profile.displayName)
            #expect(policy.safetyMode == profile.promptAppSafetyMode)

            if !profile.canPresentSuggestions {
                #expect(policy.runtimeState != .userToggleAllowed)
            }

            if profile.supportLevel == .diagnosticsOnly {
                #expect([
                    HostPolicyRuntimeState.diagnosticsOnly,
                    .disabled,
                    .proofModeOnly
                ].contains(policy.runtimeState))
            }
        }
    }

    @Test("Prompt hosts have exact version or blocked-state proof policy")
    func promptHostsHaveExactVersionOrBlockedStateProofPolicy() throws {
        let catalog = HostCompatibilityPolicyCatalog.mvp

        for bundleIdentifier in [
            "com.openai.atlas"
        ] {
            let policy = try #require(catalog.policy(for: bundleIdentifier))
            #expect(policy.hostVersion.isExact)
            #expect(policy.runtimeState == .userToggleAllowed)
            #expect(policy.proofState == .pending)
            #expect(policy.killSwitch == .perHostDisable)
        }

        let codex = try #require(catalog.policy(for: "com.openai.codex"))
        #expect(codex.hostVersion == .exact(
            shortVersion: "26.519.22136",
            build: "3003",
            source: "/Applications/Codex.app"
        ))
        #expect(codex.runtimeState == .userToggleAllowed)
        #expect(codex.killSwitch == .perHostDisable)

        for bundleIdentifier in [
            "com.openai.chat",
            "com.openai.ChatGPT",
            "com.tinyspeck.slackmacgap",
            "ru.keepcoder.Telegram",
            "com.hnc.Discord"
        ] {
            let policy = try #require(catalog.policy(for: bundleIdentifier))
            #expect(!policy.hostVersion.isExact)
            #expect(policy.runtimeState == .userToggleAllowed)
            #expect(policy.proofState == .pending)
            #expect(policy.killSwitch == .perHostDisable)
        }
    }

    @Test("Prompt safety policies keep proof state explicit")
    func promptSafetyPoliciesKeepProofStateExplicit() throws {
        let profiles = CompatibilityProfileStore.mvp.profiles
        let catalog = HostCompatibilityPolicyCatalog.mvp
        let wordOnlyPolicies = catalog.policies.values.filter { $0.safetyMode == .wordOnly }

        #expect(!wordOnlyPolicies.isEmpty)
        for policy in wordOnlyPolicies {
            let profile = try #require(profiles[policy.bundleIdentifier])
            #expect(profile.supportsOneWordAcceptance)
            if profile.supportsFullAcceptance {
                #expect(profile.supportsFullAcceptance)
                #expect(!profile.requiresNoSubmitAcceptanceProof)
                #expect(policy.killSwitch == .perHostDisable)
            } else {
                #expect(!profile.supportsFullAcceptance)
                #expect(profile.requiresNoSubmitAcceptanceProof)
                #expect([.proofModeRequired, .perHostDisable].contains(policy.killSwitch))
            }
            if policy.proofState != .pending {
                #expect(!policy.proofArtifacts.isEmpty)
            }
        }
    }

    @Test("Experimental chat surfaces use not-prompt mode while control-character safety remains universal")
    func experimentalChatSurfacesUseNotPromptMode() throws {
        let experimentalChatBundleIdentifiers = [
            "com.tinyspeck.slackmacgap",
            "ru.keepcoder.Telegram",
            "com.hnc.Discord",
            "com.hnc.DiscordPTB",
            "com.hnc.DiscordCanary"
        ]
        let profiles = CompatibilityProfileStore.mvp.profiles
        let policies = HostCompatibilityPolicyCatalog.mvp.policies

        for bundleIdentifier in experimentalChatBundleIdentifiers {
            #expect(try #require(profiles[bundleIdentifier]).promptAppSafetyMode == .notPrompt)
            #expect(try #require(policies[bundleIdentifier]).safetyMode == .notPrompt)
        }
        #expect(try #require(profiles["com.apple.MobileSMS"]).promptAppSafetyMode == .wordOnly)
    }

    @Test("Normal beta toggles include default-on dogfood apps")
    func normalBetaTogglesIncludeDefaultOnDogfoodApps() throws {
        let catalog = HostCompatibilityPolicyCatalog.mvp
        let betaSafeBundles = Set([
            "com.apple.TextEdit",
            "com.apple.Notes",
            "md.obsidian",
            "com.apple.mail",
            "com.google.Chrome",
            "com.apple.Safari",
            "com.openai.codex",
            "com.openai.atlas",
            "com.openai.chat",
            "com.openai.ChatGPT",
            "com.anthropic.claude-code",
            "com.anthropic.claudefordesktop",
            "com.tinyspeck.slackmacgap",
            "ru.keepcoder.Telegram",
            "notion.id",
            "com.hnc.Discord",
            "com.hnc.DiscordPTB",
            "com.hnc.DiscordCanary",
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92"
        ])

        let userToggleBundles = Set(catalog.policies.values
            .filter { $0.runtimeState == .userToggleAllowed }
            .map(\.bundleIdentifier))

        #expect(userToggleBundles == betaSafeBundles)
        #expect(try #require(catalog.policy(for: "com.apple.MobileSMS")).runtimeState == .proofModeOnly)
        #expect(try #require(catalog.policy(for: "com.apple.MobileSMS")).killSwitch == .proofModeRequired)
        #expect(try #require(catalog.policy(for: "com.openai.codex")).runtimeState == .userToggleAllowed)
        #expect(try #require(catalog.policy(for: "com.anthropic.claudefordesktop")).runtimeState == .userToggleAllowed)
        #expect(try #require(catalog.policy(for: "com.anthropic.claude-code")).runtimeState == .userToggleAllowed)
    }

    @Test("Runtime state keeps disabled and proof-only hosts closed by default")
    func runtimeStateKeepsDisabledAndProofOnlyHostsClosedByDefault() {
        #expect(HostPolicyRuntimeState.userToggleAllowed.allowsSuggestions(
            userDisabled: false,
            proofModeEnabled: false
        ))
        #expect(!HostPolicyRuntimeState.userToggleAllowed.allowsSuggestions(
            userDisabled: true,
            proofModeEnabled: true
        ))
        #expect(!HostPolicyRuntimeState.proofModeOnly.allowsSuggestions(
            userDisabled: false,
            proofModeEnabled: false
        ))
        #expect(HostPolicyRuntimeState.proofModeOnly.allowsSuggestions(
            userDisabled: false,
            proofModeEnabled: true
        ))
        #expect(!HostPolicyRuntimeState.diagnosticsOnly.allowsSuggestions(
            userDisabled: false,
            proofModeEnabled: true
        ))
        #expect(!HostPolicyRuntimeState.disabled.allowsSuggestions(
            userDisabled: false,
            proofModeEnabled: true
        ))
    }
}
