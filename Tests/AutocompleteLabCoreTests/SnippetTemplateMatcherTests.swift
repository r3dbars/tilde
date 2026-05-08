import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Snippet template matcher")
struct SnippetTemplateMatcherTests {
    @Test("Matches explicit trigger at cursor for an allowed app")
    func matchesExplicitTriggerForAllowedApp() throws {
        let matcher = SnippetTemplateMatcher()
        let template = SnippetTemplate(
            id: "thanks",
            trigger: ";ty",
            replacement: "thank you",
            allowedBundleIdentifiers: ["com.apple.TextEdit"]
        )

        let match = try #require(matcher.match(
            textBeforeCursor: "Quick note ;ty",
            appBundleIdentifier: "COM.APPLE.TEXTEDIT",
            templates: [template]
        ))

        #expect(match.template == template)
        #expect(match.triggerUTF16Location == "Quick note ".utf16.count)
        #expect(match.triggerUTF16Length == ";ty".utf16.count)
        #expect(match.visibleText == "thank you")
    }

    @Test("Requires app allowlist and explicit trigger boundary")
    func requiresAllowedAppAndBoundary() {
        let matcher = SnippetTemplateMatcher()
        let template = SnippetTemplate(
            id: "thanks",
            trigger: ";ty",
            replacement: "thank you",
            allowedBundleIdentifiers: ["com.apple.TextEdit"]
        )

        #expect(matcher.match(
            textBeforeCursor: "Quick note ;ty",
            appBundleIdentifier: "com.apple.Notes",
            templates: [template]
        ) == nil)
        #expect(matcher.match(
            textBeforeCursor: "Quick note;ty",
            appBundleIdentifier: "com.apple.TextEdit",
            templates: [template]
        ) == nil)
    }

    @Test("Rejects unsafe triggers and replacements")
    func rejectsUnsafeTriggersAndReplacements() {
        let matcher = SnippetTemplateMatcher()
        let templates = [
            SnippetTemplate(
                id: "no-prefix",
                trigger: "ty",
                replacement: "thank you",
                allowedBundleIdentifiers: ["com.apple.TextEdit"]
            ),
            SnippetTemplate(
                id: "unsafe-trigger",
                trigger: ";send!",
                replacement: "thank you",
                allowedBundleIdentifiers: ["com.apple.TextEdit"]
            ),
            SnippetTemplate(
                id: "newline",
                trigger: ";nl",
                replacement: "thank you\nsend",
                allowedBundleIdentifiers: ["com.apple.TextEdit"]
            ),
            SnippetTemplate(
                id: "disabled",
                trigger: ";off",
                replacement: "thank you",
                allowedBundleIdentifiers: ["com.apple.TextEdit"],
                isEnabled: false
            )
        ]

        for template in templates {
            #expect(matcher.match(
                textBeforeCursor: "Quick note \(template.trigger)",
                appBundleIdentifier: "com.apple.TextEdit",
                templates: [template]
            ) == nil)
        }
    }

    @Test("Prefers the longest matching trigger")
    func prefersLongestMatchingTrigger() throws {
        let matcher = SnippetTemplateMatcher()
        let short = SnippetTemplate(
            id: "short",
            trigger: ";sig",
            replacement: "short signature",
            allowedBundleIdentifiers: ["com.apple.TextEdit"]
        )
        let long = SnippetTemplate(
            id: "long",
            trigger: ";signature",
            replacement: "long signature",
            allowedBundleIdentifiers: ["com.apple.TextEdit"]
        )

        let match = try #require(matcher.match(
            textBeforeCursor: "Quick note ;signature",
            appBundleIdentifier: "com.apple.TextEdit",
            templates: [short, long]
        ))

        #expect(match.template.id == "long")
    }

    @Test("Trace metadata exposes only shape")
    func traceMetadataExposesOnlyShape() throws {
        let matcher = SnippetTemplateMatcher()
        let match = try #require(matcher.match(
            textBeforeCursor: "Quick note ;addr",
            appBundleIdentifier: "com.apple.TextEdit",
            templates: [
                SnippetTemplate(
                    id: "home-address",
                    trigger: ";addr",
                    replacement: "123 Private Street",
                    allowedBundleIdentifiers: ["com.apple.TextEdit"]
                )
            ]
        ))
        let metadata = match.traceMetadata

        #expect(metadata["snippetTriggerChars"] == "5")
        #expect(metadata["snippetReplacementChars"] == "18")
        #expect(metadata["snippetAllowedAppCount"] == "1")

        let json = String(decoding: try JSONEncoder().encode(metadata), as: UTF8.self)
        #expect(!json.localizedCaseInsensitiveContains("Private"))
        #expect(!json.localizedCaseInsensitiveContains("address"))
        #expect(!json.localizedCaseInsensitiveContains(";addr"))
    }
}
