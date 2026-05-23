import Testing
@testable import AutocompleteLabCore

@Suite("Autocomplete behavior profiles")
struct AutocompleteBehaviorProfileTests {
    @Test("Defines every product behavior profile")
    func definesEveryProductBehaviorProfile() {
        #expect(AutocompleteBehaviorProfileID.allCases == [
            .casualChat,
            .email,
            .notes,
            .coding,
            .docsProse,
            .bullets,
            .forms,
            .search,
            .aiChat
        ])
    }

    @Test("Email profile blocks invented commitments, names, and deadlines")
    func emailProfileBlocksInventedCommitmentsNamesAndDeadlines() {
        let profile = AutocompleteBehaviorProfile.profile(.email)
        let guidance = profile.promptGuidance.joined(separator: " ")

        #expect(profile.maxVisibleWords == 8)
        #expect(profile.maxGeneratedTokens == 16)
        #expect(guidance.contains("Do not invent commitments"))
        #expect(guidance.contains("names"))
        #expect(guidance.contains("deadlines"))
        #expect(guidance.contains("dates"))
        #expect(profile.suppressionDefaults.suppressesFreshParagraphStart)
    }

    @Test("Bullets profile preserves marker and indent")
    func bulletsProfilePreservesMarkerAndIndent() {
        let profile = AutocompleteBehaviorProfile.profile(.bullets)
        let guidance = profile.promptGuidance.joined(separator: " ")

        #expect(guidance.contains("Preserve the current bullet marker"))
        #expect(guidance.contains("numbering style"))
        #expect(guidance.contains("indentation"))
        #expect(!profile.suppressionDefaults.suppressesSuggestionsByDefault)
    }

    @Test("Coding profile is conservative and does not invent APIs")
    func codingProfileIsConservativeAndDoesNotInventAPIs() {
        let profile = AutocompleteBehaviorProfile.profile(.coding)
        let guidance = profile.promptGuidance.joined(separator: " ")

        #expect(profile.maxVisibleWords == 5)
        #expect(profile.maxGeneratedTokens == 8)
        #expect(guidance.contains("Be conservative in code"))
        #expect(guidance.contains("Do not invent APIs"))
        #expect(guidance.contains("imports"))
        #expect(guidance.contains("blocks"))
    }

    @Test("AI chat profile is slider-capable and no-submit")
    func aiChatProfileIsSliderCapableAndNoSubmit() {
        let profile = AutocompleteBehaviorProfile.profile(.aiChat)
        let guidance = profile.promptGuidance.joined(separator: " ")

        #expect(profile.maxVisibleWords == 5)
        #expect(profile.maxGeneratedTokens == 9)
        #expect(!profile.suppressionDefaults.allowsFullAccept)
        #expect(!profile.suppressionDefaults.allowsSubmitLikeCompletions)
        #expect(guidance.contains("tiny unless the user explicitly raises the visible word limit"))
        #expect(guidance.contains("Never suggest sending"))
        #expect(guidance.contains("pressing Enter or Return"))
        #expect(guidance.contains("slash commands"))
        #expect(guidance.contains("@ references"))
        #expect(guidance.contains("shell text"))
    }

    @Test("Forms and search profiles suppress by default")
    func formsAndSearchProfilesSuppressByDefault() {
        for id in [AutocompleteBehaviorProfileID.forms, .search] {
            let profile = AutocompleteBehaviorProfile.profile(id)

            #expect(profile.suppressionDefaults.suppressesSuggestionsByDefault)
            #expect(profile.maxVisibleWords == 1)
            #expect(profile.maxGeneratedTokens == 3)
            #expect(!profile.suppressionDefaults.allowsFullAccept)
        }
    }

    @Test("Resolver maps field kinds before app defaults")
    func resolverMapsFieldKindsBeforeAppDefaults() {
        let resolver = AutocompleteBehaviorProfileResolver()

        #expect(resolver.profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: "com.apple.Notes",
            fieldKind: .search
        )).id == .search)

        #expect(resolver.profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: "com.openai.codex",
            fieldKind: .form
        )).id == .forms)
    }

    @Test("Resolver maps generic list shaped lines to bullets")
    func resolverMapsGenericListShapedLinesToBullets() {
        let resolver = AutocompleteBehaviorProfileResolver()

        #expect(resolver.profile(for: AutocompleteBehaviorProfileInput(
            fieldKind: .multilineCompose,
            currentLineStructure: CurrentLineStructure.from(textBeforeCursor: "- Follow u")
        )).id == .bullets)

        #expect(resolver.profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: "com.apple.TextEdit",
            fieldKind: .multilineCompose,
            currentLineStructure: CurrentLineStructure.from(textBeforeCursor: "- [ ] Follow u")
        )).id == .bullets)
    }

    @Test("Resolver keeps safety profiles ahead of list shape")
    func resolverKeepsSafetyProfilesAheadOfListShape() {
        let resolver = AutocompleteBehaviorProfileResolver()
        let lineStructure = CurrentLineStructure.from(textBeforeCursor: "- [ ] Follow u")

        #expect(resolver.profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: "com.openai.codex",
            fieldKind: .multilineCompose,
            currentLineStructure: lineStructure
        )).id == .aiChat)

        #expect(resolver.profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: "com.apple.TextEdit",
            fieldKind: .search,
            currentLineStructure: lineStructure
        )).id == .search)
    }

    @Test("Resolver maps common app bundles")
    func resolverMapsCommonAppBundles() {
        let resolver = AutocompleteBehaviorProfileResolver()

        #expect(resolver.profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: "com.apple.mail"
        )).id == .email)
        #expect(resolver.profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: "com.apple.Notes"
        )).id == .notes)
        #expect(resolver.profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: "com.openai.codex"
        )).id == .aiChat)
        #expect(resolver.profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: "com.apple.dt.Xcode"
        )).id == .coding)
    }

    @Test("Trace metadata is short and trace-safe")
    func traceMetadataIsShortAndTraceSafe() {
        let profile = AutocompleteBehaviorProfile.profile(.email)
        let metadata = profile.traceMetadata

        #expect(metadata == [
            "behaviorProfile": "email",
            "behaviorProfileMaxVisibleWords": "8",
            "behaviorProfileMaxGeneratedTokens": "16",
            "behaviorProfileSuppressedByDefault": "false",
            "behaviorProfileSuppressesFreshParagraphStart": "true",
            "behaviorProfileSuppressesBlankLine": "true",
            "behaviorProfileSuppressesQuestions": "false",
            "behaviorProfileFullAccept": "true",
            "behaviorProfileSubmitLikeCompletions": "false"
        ])
        #expect(!metadata.values.joined(separator: " ").contains("commitments"))
        #expect(!metadata.values.joined(separator: " ").contains("deadline"))
    }
}
